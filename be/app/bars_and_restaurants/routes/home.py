from fastapi import APIRouter, Depends, Query
from typing import Optional, List
from pydantic import BaseModel
import time

from app.database import database
from app.auth.middleware import get_current_active_user, get_optional_user, AuthUser
from app.auth.auth_models import User
from app.bars_and_restaurants.services.cart_service import CartService
from app.bars_and_restaurants.services.places_service import find_bars_near_location, reverse_geocode
from app.bars_and_restaurants.routes.bars import get_bars_by_ids, get_bars_setup_status
from app.bars_and_restaurants.models.relational_models import Promotion as PromotionModel
from app.bars_and_restaurants.services.image_upload import generate_presigned_url, extract_s3_key

home_router = APIRouter(prefix="/home", tags=["Home"])

# --- Response Models ---

class ActiveCartSummary(BaseModel):
    item_count: int
    total: float
    bar_id: int
    bar_name: str

class UserStatus(BaseModel):
    active_cart: Optional[ActiveCartSummary] = None
    unread_notifications: int = 0

class NearbyBarSummary(BaseModel):
    id: int
    name: str
    image_url: Optional[str] = None
    distance_meters: Optional[float] = None
    rating: float = 0.0
    is_open: bool = False # Simplified logic for now
    category: Optional[str] = None
    primary_promotion: Optional[str] = None  # happy_hour | cashback | promotion
    promotion_text: Optional[str] = None


class PromoSummaryModel(BaseModel):
    total: int
    pro_coupons: int = 0
    cashback: int = 0
    promotions: int = 0
    campaigns: int = 0


class NearestVenue(BaseModel):
    id: int
    name: str
    distance_meters: Optional[float] = None

class TrendingItem(BaseModel):
    id: int
    name: str
    price: float
    promotional_price: Optional[float] = None
    image_url: Optional[str] = None
    is_promoted: bool = False

class TrendingDrinksResponse(BaseModel):
    most_wanted: List[TrendingItem] = []
    hottest: List[TrendingItem] = []

class ActivePromotion(BaseModel):
    id: int
    title: str
    description: Optional[str] = None
    discount_type: str
    discount_value: float
    start_time: Optional[str] = None
    end_time: Optional[str] = None
    image_url: Optional[str] = None

class HomeResponse(BaseModel):
    user_status: Optional[UserStatus] = None
    nearby_bars: List[NearbyBarSummary] = []
    trending_drinks: TrendingDrinksResponse
    active_promotions: List[ActivePromotion] = []
    location_mismatch: bool = False
    detected_country: Optional[str] = None
    # Additive Home fields (absent/None => clients show a plain greeting)
    display_name: Optional[str] = None
    promo_summary: Optional[PromoSummaryModel] = None
    nearest_venue: Optional[NearestVenue] = None


# --- Helpes ---

async def get_active_cart_summary(user_id: int) -> Optional[ActiveCartSummary]:
    from app.bars_and_restaurants.models.cart_models import Cart as CartModel, CartItem as CartItemModel
    from app.bars_and_restaurants.models.relational_models import Bar as BarModel
    
    # Get user's cart
    cart = await database.fetch_one(
        CartModel.__table__.select().where(CartModel.user_id == user_id)
    )
    if not cart:
        return None
        
    # Get items
    items = await database.fetch_all(
        CartItemModel.__table__.select().where(CartItemModel.cart_id == cart["id"])
    )
    if not items:
        return None
        
    item_count = sum(item["quantity"] for item in items)
    total = sum(item["quantity"] * item["unit_price"] for item in items)
    
    # Get bar info (assuming single bar for now as per checkout limitations)
    if not items:
        return None
        
    bar_id = items[0]["bar_id"]
    bar = await database.fetch_one(
        BarModel.__table__.select().where(BarModel.id == bar_id)
    )
    
    return ActiveCartSummary(
        item_count=item_count,
        total=float(total),
        bar_id=bar_id,
        bar_name=bar["name"] if bar else "Unknown Bar"
    )

async def get_trending_items(limit: int = 5) -> List[TrendingItem]:
    # Aggregation: Most ordered items in the last 7 days (or all time if simpler for now)
    # Using SQL for aggregation on order_items
    query = """
        SELECT mi.id, mi.name, mi.price, mi.promotional_price, mi.picture, 
               mi.available, SUM(oi.quantity) as qty
        FROM order_items oi
        JOIN menu_items mi ON oi.menu_item_id = mi.id
        JOIN orders o ON oi.order_id = o.id
        WHERE o.status != 'cancelled'
        GROUP BY mi.id, mi.name, mi.price, mi.promotional_price, mi.picture, mi.available
        ORDER BY qty DESC
        LIMIT :limit
    """
    rows = await database.fetch_all(query, {"limit": limit})
    
    current_time = int(time.time())
    results = []
    for row in rows:
         # Sign image URL if present
        img_url = row["picture"]
        if img_url:
            img_url = generate_presigned_url(extract_s3_key(img_url))
            
        results.append(TrendingItem(
            id=row["id"],
            name=row["name"],
            price=float(row["price"] or 0),
            promotional_price=float(row["promotional_price"]) if row["promotional_price"] else None,
            image_url=img_url,
            is_promoted=row["promotional_price"] is not None and row["promotional_price"] < row["price"]
        ))
    return results

# --- Main Endpoint ---

@home_router.get("/", response_model=HomeResponse)
async def get_home_dashboard(
    latitude: Optional[float] = Query(None, description="Latitude for nearby discovery"),
    longitude: Optional[float] = Query(None, description="Longitude for nearby discovery"),
    current_user: Optional[AuthUser] = Depends(get_optional_user)
):
    # 1. User Status (if logged in)
    user_status = None
    if current_user:
        active_cart = await get_active_cart_summary(current_user.id)
        
        # Real notification fetching
        try:
            count_query = "SELECT COUNT(id) FROM notifications WHERE user_id = :user_id AND is_read = false"
            unread_count_val = await database.fetch_val(count_query, {"user_id": current_user.id})
            unread_count_int = int(unread_count_val) if unread_count_val else 0
        except Exception as e:
            # Fallback to 0 if migration hasn't run yet
            print(f"⚠️ Warning: notifications table not ready: {e}")
            unread_count_int = 0
            
        user_status = UserStatus(
            active_cart=active_cart,
            unread_notifications=unread_count_int 
        )
    
    # 1.1 Location Mismatch Detection
    location_mismatch = False
    detected_country = None
    if current_user and latitude is not None and longitude is not None:
        detected_country = await reverse_geocode(latitude, longitude)
        user_country = current_user.country_code or "BR"
        
        if detected_country and detected_country != user_country:
            location_mismatch = True
    
    # 2. Nearby Bars (ready venues only; nearest-first, independent of ad tiers)
    from app.bars_and_restaurants.services import venue_discovery as vd

    nearby_bars = []
    nearest_venue = None
    promo_summary = None
    has_location = latitude is not None and longitude is not None
    try:
        if has_location:
            venues = await vd.located_ready_venues(database, latitude, longitude, vd.DISCOVERY_RADIUS_M)
        else:
            venues = await vd.country_ready_venues(
                database, getattr(current_user, "country_code", None) if current_user else None, limit=10
            )
        snapshot = None
        if venues:
            distances = {v["id"]: v.get("approximateLocation") for v in venues}
            snapshot = await vd.load_promo_snapshot(database, [v["id"] for v in venues], distances)
        if has_location and venues:
            first = venues[0]
            nearest_venue = NearestVenue(
                id=first["id"], name=first["name"], distance_meters=first.get("approximateLocation")
            )
        if current_user:
            summary = await vd.compute_promo_summary(
                database, current_user.id, current_user.is_pro(), snapshot if has_location else None
            )
            promo_summary = PromoSummaryModel(**summary.__dict__)
        vd.annotate(venues, snapshot)
        for b in venues[:10]:  # carousel limit applies after count/nearest selection
            nearby_bars.append(NearbyBarSummary(
                id=b["id"],
                name=b["name"],
                image_url=b.get("image_url"),
                distance_meters=b.get("approximateLocation"),
                rating=b.get("rating") or 0.0,
                is_open=True,
                category=b.get("category"),
                primary_promotion=b.get("primary_promotion"),
                promotion_text=b.get("promotion_text"),
            ))
    except Exception as e:  # discovery failure must not break Home; summary stays unknown
        print(f"⚠️ Warning: home discovery unavailable: {e}")
        nearby_bars, nearest_venue, promo_summary = [], None, None

    # 3. Trending Drinks
    # "Most Wanted" = Top ordered
    # "Hottest" = Promoted items (simulated for now by reusing most wanted or specific query)
    most_wanted = await get_trending_items(limit=5)
    
    # For Hottest, query items actively promoted and order by highest discount percentage relative to price
    hottest_query = """
        SELECT id, name, price, promotional_price, picture 
        FROM menu_items 
        WHERE promotional_price IS NOT NULL AND price > 0 AND available = true
        ORDER BY ((price - promotional_price) / price) DESC, id DESC
        LIMIT 5
    """
    hottest_rows = await database.fetch_all(hottest_query)
    current_time = int(time.time())
    hottest = []
    for row in hottest_rows:
        img_url = row["picture"]
        if img_url:
            img_url = generate_presigned_url(extract_s3_key(img_url))
            
        hottest.append(TrendingItem(
            id=row["id"],
            name=row["name"],
            price=float(row["price"] or 0),
            promotional_price=float(row["promotional_price"]),
            image_url=img_url,
            is_promoted=True
        ))

    # 4. Active Promotions (Global or nearby bars)
    # For now fetching global latest active promotions
    promo_query = """
        SELECT * FROM promotions 
        WHERE is_active = true 
        ORDER BY created_at DESC 
        LIMIT 5
    """
    promo_rows = await database.fetch_all(promo_query)
    active_promotions = []
    for row in promo_rows:
        img_url = row["image_url"]
        if img_url:
             img_url = generate_presigned_url(extract_s3_key(img_url))
        
        active_promotions.append(ActivePromotion(
            id=row["id"],
            title=row["title"],
            description=row["description"],
            discount_type=row["discount_type"],
            discount_value=float(row["discount_value"]),
            start_time=str(row["start_time"]) if row["start_time"] else None,
            end_time=str(row["end_time"]) if row["end_time"] else None,
            image_url=img_url
        ))

    return HomeResponse(
        user_status=user_status,
        nearby_bars=nearby_bars,
        trending_drinks=TrendingDrinksResponse(
            most_wanted=most_wanted,
            hottest=hottest
        ),
        active_promotions=active_promotions,
        location_mismatch=location_mismatch,
        detected_country=detected_country,
        display_name=(current_user.display_name or None) if current_user else None,
        promo_summary=promo_summary,
        nearest_venue=nearest_venue,
    )
