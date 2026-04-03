from fastapi import APIRouter, Depends, Query
from typing import Optional, List
from pydantic import BaseModel
import time

from app.database import database
from app.auth.middleware import get_current_active_user, get_optional_user
from app.auth.auth_models import User
from app.bars_and_restaurants.services.cart_service import CartService
from app.bars_and_restaurants.services.places_service import find_bars_near_location
from app.bars_and_restaurants.routes.bars import get_bars_by_ids
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
    rating: float = 0.0 # Placeholder for now
    is_open: bool = False # Simplified logic for now

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
    lat: Optional[float] = None,
    lng: Optional[float] = None,
    current_user: Optional[User] = Depends(get_optional_user)
):
    # 1. User Status (if logged in)
    user_status = None
    if current_user:
        active_cart = await get_active_cart_summary(current_user["id"])
        
        # Real notification fetching
        count_query = "SELECT COUNT(id) FROM notifications WHERE user_id = :user_id AND is_read = false"
        unread_count_val = await database.fetch_val(count_query, {"user_id": current_user["id"]})
        unread_count_int = int(unread_count_val) if unread_count_val else 0
        
        user_status = UserStatus(
            active_cart=active_cart,
            unread_notifications=unread_count_int 
        )
    
    # 2. Nearby Bars
    nearby_bars = []
    if lat is not None and lng is not None:
        bar_ids = await find_bars_near_location(lat, lng, max_distance=10000) # 10km default
        if bar_ids:
            # Reusing get_bars_by_ids from bars.py which handles image signing and merging
            bars_data = await get_bars_by_ids(bar_ids)
            
            # Map to response model
            for b in bars_data[:10]: # Limit to 10
                 # Simple logic for is_open (can be improved to check operating hours)
                 # Reusing the structure from bars.py output
                nearby_bars.append(NearbyBarSummary(
                    id=b["id"],
                    name=b["name"],
                    image_url=b.get("image_url"),
                    distance_meters=b.get("approximateLocation"),
                    rating=b.get("rating", 4.5), # Mock rating default
                    is_open=True # Default to true for list view for now, or fetch sophisticated status
                ))

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
        active_promotions=active_promotions
    )
