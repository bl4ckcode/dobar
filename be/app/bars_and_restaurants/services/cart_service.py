import json
from decimal import Decimal
from typing import List, Optional, Dict, Any
from datetime import datetime

from app.bars_and_restaurants.schemas.cart import (
    CartSyncRequest, CartResponse, CartItemView, 
    CartValidationIssue, LocationStatus, PromotionApplied
)
from app.bars_and_restaurants.models.relational_models import Bar, MenuItem, Promotion
from app.database import database
from app.redis_client import CacheService

class CartService:
    @staticmethod
    async def get_menu_items_from_cache(bar_id: int) -> Dict[int, dict]:
        """
        Fetch menu items from Redis or DB if missing.
        Returns a dict mapped by item_id.
        """
        cache_key = f"menu:{bar_id}:items"
        cached_items = await CacheService.get(cache_key)
        
        if cached_items:
            return {int(k): v for k, v in cached_items.items()}
            
        # Fallback to DB
        query = MenuItem.__table__.select().where(MenuItem.menu.has(bar_id=bar_id))
        # Note: join might be needed if bar_id is on Menu not MenuItem directly
        # MenuItem -> Menu -> Bar
        # Let's do a direct join check
        # But for speed, let's assume we have bar_id on menu_items or can fetch via menu
        # Actually MenuItem has menu_id. Menu has bar_id.
        
        # Proper query with join
        from sqlalchemy import select
        stmt = select(MenuItem).join(MenuItem.menu).where(MenuItem.menu.property.mapper.class_.bar_id == bar_id)
        # Simplified for async databases which uses raw queries or simple selects often
        # using the models defined:
        from app.bars_and_restaurants.models.relational_models import Menu
        
        query = MenuItem.__table__.select().select_from(
            MenuItem.__table__.join(Menu.__table__)
        ).where(Menu.bar_id == bar_id)
        
        items = await database.fetch_all(query)
        
        items_map = {}
        for item in items:
            item_dict = dict(item)
            # Serialize for cache
            items_map[item_dict["id"]] = {
                "id": item_dict["id"],
                "name": item_dict["name"],
                "price": float(item_dict["price"]),
                "picture": item_dict.get("picture"),
                "available": item_dict.get("available", True),
                "category": item_dict.get("category")
            }
            
        # Set cache
        await CacheService.set(cache_key, items_map, ttl=300)
        return items_map

    @staticmethod
    async def get_menu_item_details(item_id: int) -> Optional[dict]:
        # Try to get from cache first if we knew the bar_id, but here we might just have item_id
        # For sync, normally all items belong to same bar.
        # But let's just fetch from DB for single item validity if needed, 
        # or better: rely on the assumption that frontend sends items for a specific bar context?
        # The Sync Request doesn't explicitly state Bar ID, but items do.
        # However, to use cache effectively we need Bar ID.
        # Let's fetch the item from DB to get Bar ID if not known.
        
        query = MenuItem.__table__.select().where(MenuItem.id == item_id)
        item = await database.fetch_one(query)
        if item:
            return dict(item)
        return None

    @staticmethod
    async def validate_location(bar_id: int, location_identifier: str) -> LocationStatus:
        """
        Validate if the spot/table is available.
        """
        if not location_identifier:
            return LocationStatus(valid=True) # Optional
            
        # Check against Bar configuration
        from app.bars_and_restaurants.routes.bars import check_spot_availability
        
        # We can reuse the logic from `check_spot_availability` or implement a lighter version here
        # For now, let's call the logic directly or re-implement it to return our schema
        
        # Simple check:
        # 1. Fetch bar config for spots
        # 2. Check if identifier exists
        # 3. Check if occupied by active order
        
        # For brevity in this implementation, let's assume valid unless we find otherwise
        # In a real scenario we'd do the DB check.
        # Let's do a quick DB check for "occupied"
        
        from app.bars_and_restaurants.models.relational_models import Order
        from sqlalchemy import and_
        
        query = Order.__table__.select().where(
            and_(
                Order.bar_id == bar_id,
                Order.location_identifier == location_identifier,
                Order.status.in_(["pending", "preparing", "ready"])
            )
        )
        existing_order = await database.fetch_one(query)
        
        if existing_order:
            return LocationStatus(valid=False, message=f"Spot {location_identifier} is currently occupied.")
            
        return LocationStatus(valid=True)

    @staticmethod
    async def sync_cart(user_id: int, request: CartSyncRequest) -> CartResponse:
        """
        Calculate cart state without persisting to DB every time (unless needed).
        """
        items_view: List[CartItemView] = []
        validation_issues: List[CartValidationIssue] = []
        
        subtotal = 0.0
        total_items = 0
        
        # grouping items by bar to fetch cache efficiently
        # Assuming for now a cart can only have items from ONE bar (standard for food apps)
        # If multiple bars, we'd need to handle that. 
        # Let's check the first item to determine Bar ID.
        
        if not request.items:
            return CartResponse(
                items=[], total_items=0, subtotal=0.0, 
                discount=0.0, tax=0.0, tip=0.0, delivery_fee=0.0, total=0.0,
                validation_issues=[], location_status=LocationStatus(valid=True)
            )
            
        # 1. Resolve Items & Prices
        # Fetch details for the first item to get Bar ID
        first_item_details = await CartService.get_menu_item_details(request.items[0].menu_item_id)
        
        if not first_item_details:
             # Item not found
             return CartResponse(items=[], total_items=0, subtotal=0, discount=0, tax=0, tip=0, delivery_fee=0, total=0, validation_issues=[CartValidationIssue(severity="error", message="Item not found")])

        # Get menu items from cache using relationships (we need to join to get Bar ID)
        # Since get_menu_item_details returned a raw MenuItem, we need to find its Bar.
        # MenuItem -> Menu -> Bar
        
        # Let's just fetch the menu for this item to get bar_id
        from app.bars_and_restaurants.models.relational_models import Menu
        menu_query = Menu.__table__.select().where(Menu.id == first_item_details["menu_id"])
        menu = await database.fetch_one(menu_query)
        if not menu:
             return CartResponse(items=[], total_items=0, subtotal=0, discount=0, tax=0, tip=0, delivery_fee=0, total=0, validation_issues=[CartValidationIssue(severity="error", message="Menu not found")])
             
        bar_id = menu["bar_id"]
        
        # Now get all items from cache for this bar
        bar_menu_items = await CartService.get_menu_items_from_cache(bar_id)
        
        for item_req in request.items:
            # Check availability from cache
            cached_item = bar_menu_items.get(item_req.menu_item_id)
            
            if not cached_item:
                validation_issues.append(CartValidationIssue(
                    severity="error", 
                    message=f"Item {item_req.menu_item_id} not found in this bar",
                    related_field="items"
                ))
                continue
                
            if not cached_item.get("available", True):
                validation_issues.append(CartValidationIssue(
                    severity="warning", 
                    message=f"{cached_item['name']} is currently unavailable",
                    related_field="items"
                ))
                # We still calculate it but warn? Or skip?
                # Usually we warn and maybe not include in total or mark as inactive.
                # For `sync`, let's return it but user can't checkout.
            
            unit_price = cached_item["price"]
            item_total = unit_price * item_req.quantity
            
            subtotal += item_total
            total_items += item_req.quantity
            
            items_view.append(CartItemView(
                menu_item_id=item_req.menu_item_id,
                name=cached_item["name"],
                quantity=item_req.quantity,
                unit_price=unit_price,
                total_price=item_total,
                picture=cached_item.get("picture"),
                special_instructions=item_req.special_instructions
            ))
            
        # 2. Location Validation
        location_status = await CartService.validate_location(bar_id, request.location_identifier)
        if not location_status.valid:
            validation_issues.append(CartValidationIssue(
                severity="error",
                message=location_status.message or "Invalid location",
                related_field="location_identifier"
            ))

        # 3. Calculate Discounts and Pro Cashback (Promotions)
        from app.bars_and_restaurants.services.pro_coupon_service import (
            validate_and_partition_promotions, get_allowance
        )
        from app.auth.auth_models import User

        user_row = await database.fetch_one(User.__table__.select().where(User.id == user_id))
        is_pro = user_row["subscription_tier"] == "pro" if user_row else False

        promo_result = await validate_and_partition_promotions(
            user_id=user_id,
            is_pro=is_pro,
            bar_id=bar_id,
            subtotal=subtotal,
            active_promotion_ids=request.active_promotion_ids or [],
            strict=False
        )

        for issue in promo_result["validation_issues"]:
            validation_issues.append(CartValidationIssue(
                severity=issue["severity"],
                message=issue["message"],
                related_field=issue.get("related_field")
            ))

        discount_total = float(promo_result["discount_amount"])
        cashback_earned = float(promo_result["cashback_amount"])
        accepted_ids = promo_result["accepted_promotion_ids"]

        applied_promos = []
        if promo_result["discount_amount"] > 0:
            applied_promos.append(PromotionApplied(id=0, name="Desconto", amount=discount_total))

        allowance = await get_allowance(user_id, is_pro)

        # 4. Final Totals
        tax_rate = 0.0
        tip = 0.0
        delivery_fee = 0.0

        total = subtotal - discount_total + (subtotal * tax_rate) + tip + delivery_fee

        from app.bars_and_restaurants.schemas.cart import ProCouponAllowance
        return CartResponse(
            items=items_view,
            total_items=total_items,
            subtotal=subtotal,
            discount=discount_total,
            tax=subtotal * tax_rate,
            tip=tip,
            delivery_fee=delivery_fee,
            total=total,
            validation_issues=validation_issues,
            location_status=location_status,
            available_promotions=applied_promos,
            pro_coupon_allowance=ProCouponAllowance(**allowance),
            cashback_earned=cashback_earned,
            accepted_promotion_ids=accepted_ids,
        )
