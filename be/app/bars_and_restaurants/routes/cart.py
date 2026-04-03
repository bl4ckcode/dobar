"""
Cart management routes.
"""

from fastapi import APIRouter, Depends, status
from sqlalchemy import and_
from typing import List, Optional
from decimal import Decimal
from datetime import datetime, timedelta

from app.auth.middleware import get_current_active_user
from app.auth.auth_models import User
from app.errors import APIError
from ..models.cart_models import Cart as CartModel, CartItem as CartItemModel, OrderItem as OrderItemModel
from ..models.relational_models import Order as OrderModel
from ..schemas.cart import Cart, CartItem, CartItemCreate, CartItemUpdate, CheckoutRequest, CheckoutResponse, CartCalculateRequest, CartSyncRequest, CartResponse
from app.database import database
from app.payment import get_payment_gateway, PaymentGateway

cart_router = APIRouter(prefix="/cart", tags=["Cart"])


async def get_or_create_cart(user_id: int) -> CartModel:
    query = CartModel.__table__.select().where(CartModel.user_id == user_id)
    cart = await database.fetch_one(query)
    
    if not cart:
        now = datetime.utcnow()
        cart_data = {"user_id": user_id, "created_at": now, "updated_at": now}
        cart_id = await database.execute(CartModel.__table__.insert().values(**cart_data))
        cart = await database.fetch_one(CartModel.__table__.select().where(CartModel.id == cart_id))
    
    return cart


async def get_cart_items(cart_id: int) -> List[CartItemModel]:
    query = CartItemModel.__table__.select().where(CartItemModel.cart_id == cart_id)
    items = await database.fetch_all(query)
    return [with_total_price(item) for item in items]


def with_total_price(item) -> dict:
    item_dict = dict(item)
    item_dict["total_price"] = item_dict["quantity"] * item_dict["unit_price"]
    return item_dict


async def calculate_cart_totals(cart_id: int) -> dict:
    """Calculate cart totals."""
    items = await get_cart_items(cart_id)
    
    total_items = sum(item["quantity"] for item in items)
    subtotal = sum(item["quantity"] * item["unit_price"] for item in items)
    
    return {
        "total_items": total_items,
        "subtotal": subtotal
    }


@cart_router.get("/", response_model=Cart)
async def get_cart(current_user: User = Depends(get_current_active_user)):
    from ..services.bundle_service import get_active_bundles_for_bar, calculate_bundles_for_cart
    
    cart = await get_or_create_cart(current_user["id"])
    items = await get_cart_items(cart["id"])
    totals = await calculate_cart_totals(cart["id"])
    
    bundles = []
    bar_ids = set(item["bar_id"] for item in items)
    for bar_id in bar_ids:
        bar_bundles = await get_active_bundles_for_bar(bar_id)
        bundles.extend(bar_bundles)
    
    bundle_result = calculate_bundles_for_cart(items, bundles)
    subtotal_after_bundles = totals["subtotal"] - bundle_result["bundle_savings"]
    
    return {
        **dict(cart),
        "items": items,
        **totals,
        "applied_bundles": bundle_result["applied_bundles"],
        "bundle_savings": bundle_result["bundle_savings"],
        "subtotal_after_bundles": subtotal_after_bundles,
        "bundle_hint": bundle_result["bundle_hint"]
    }


@cart_router.post("/calculate", response_model=Cart)
async def calculate_cart(
    request: CartCalculateRequest,
    current_user: User = Depends(get_current_active_user)
):
    from ..models.relational_models import Promotion as PromotionModel
    from ..services.wallet_service import WalletService
    from app.database import SessionLocal
    
    cart = await get_or_create_cart(current_user["id"])
    items = await get_cart_items(cart["id"])
    
    if not items:
        raise APIError.cart_empty()
    
    subtotal = sum(item["quantity"] * item["unit_price"] for item in items)
    
    discount_total = Decimal("0.00")
    promotions_applied = []
    
    if request.active_promotion_ids:
        query = PromotionModel.__table__.select().where(
            PromotionModel.id.in_(request.active_promotion_ids)
        )
        promotions = await database.fetch_all(query)
        
        db = SessionLocal()
        try:
            for promo in promotions:
                promo_dict = dict(promo)
                
                if not promo_dict.get("is_active"):
                    continue
                
                bar_id = promo_dict["bar_id"]
                
                if promo_dict["discount_type"] == "percentage":
                    discount_amount = Decimal(str(subtotal)) * (Decimal(str(promo_dict["discount_value"])) / 100)
                elif promo_dict["discount_type"] == "fixed":
                    discount_amount = Decimal(str(promo_dict["discount_value"]))
                else:
                    continue
                
                funded_by = promo_dict.get("promotion_type", "discount")
                if funded_by == "cashback":
                    from ..models.wallet_models import FundingSource
                    funding_source = FundingSource.BAR
                    
                    if not WalletService.validate_promotion_funding(db, bar_id, discount_amount, funding_source):
                        continue
                
                discount_total += discount_amount
                promotions_applied.append({
                    "id": promo_dict["id"],
                    "name": promo_dict["title"],
                    "amount": float(discount_amount)
                })
        finally:
            db.close()
    
    total = subtotal - float(discount_total)
    
    return {
        **dict(cart),
        "items": items,
        "total_items": sum(item["quantity"] for item in items),
        "subtotal": subtotal,
        "applied_bundles": [],
        "bundle_savings": 0.0,
        "subtotal_after_bundles": total,
        "bundle_hint": None
    }


@cart_router.post("/items", response_model=CartItem, status_code=status.HTTP_201_CREATED)
async def add_item_to_cart(
    item: CartItemCreate,
    current_user: User = Depends(get_current_active_user)
):
    """Add an item to the cart. If item already exists, update quantity."""
    cart = await get_or_create_cart(current_user["id"])
    
    # Check if item already exists in cart
    query = CartItemModel.__table__.select().where(
        and_(
            CartItemModel.cart_id == cart["id"],
            CartItemModel.menu_item_id == item.menu_item_id,
            CartItemModel.bar_id == item.bar_id
        )
    )
    existing_item = await database.fetch_one(query)
    
    if existing_item:
        new_quantity = existing_item["quantity"] + item.quantity
        update_query = (
            CartItemModel.__table__
            .update()
            .where(CartItemModel.id == existing_item["id"])
            .values(quantity=new_quantity, updated_at=datetime.utcnow())
        )
        await database.execute(update_query)
        
        item = await database.fetch_one(
            CartItemModel.__table__.select().where(CartItemModel.id == existing_item["id"])
        )
        return with_total_price(item)
    else:
        now = datetime.utcnow()
        item_data = {
            **item.model_dump(),
            "cart_id": cart["id"],
            "created_at": now,
            "updated_at": now
        }
        item_id = await database.execute(CartItemModel.__table__.insert().values(**item_data))
        item = await database.fetch_one(
            CartItemModel.__table__.select().where(CartItemModel.id == item_id)
        )
        return with_total_price(item)


@cart_router.put("/items/{item_id}", response_model=CartItem)
async def update_cart_item(
    item_id: int,
    item_update: CartItemUpdate,
    current_user: User = Depends(get_current_active_user)
):
    """Update the quantity of a cart item."""
    cart = await get_or_create_cart(current_user["id"])
    
    # Verify item belongs to user's cart
    query = CartItemModel.__table__.select().where(
        and_(
            CartItemModel.id == item_id,
            CartItemModel.cart_id == cart["id"]
        )
    )
    cart_item = await database.fetch_one(query)
    
    if not cart_item:
        raise APIError.cart_item_not_found()
    
    update_query = (
        CartItemModel.__table__
        .update()
        .where(CartItemModel.id == item_id)
        .values(quantity=item_update.quantity, updated_at=datetime.utcnow())
    )
    await database.execute(update_query)
    
    item = await database.fetch_one(
        CartItemModel.__table__.select().where(CartItemModel.id == item_id)
    )
    return with_total_price(item)


@cart_router.delete("/items/{item_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_cart_item(
    item_id: int,
    current_user: User = Depends(get_current_active_user)
):
    """Remove an item from the cart."""
    cart = await get_or_create_cart(current_user["id"])
    
    # Verify item belongs to user's cart
    query = CartItemModel.__table__.select().where(
        and_(
            CartItemModel.id == item_id,
            CartItemModel.cart_id == cart["id"]
        )
    )
    cart_item = await database.fetch_one(query)
    
    if not cart_item:
        raise APIError.cart_item_not_found()
    
    # Delete item
    delete_query = CartItemModel.__table__.delete().where(CartItemModel.id == item_id)
    await database.execute(delete_query)


@cart_router.delete("/", status_code=status.HTTP_204_NO_CONTENT)
async def clear_cart(current_user: User = Depends(get_current_active_user)):
    """Clear all items from the cart."""
    cart = await get_or_create_cart(current_user["id"])
    
    # Delete all items
    delete_query = CartItemModel.__table__.delete().where(CartItemModel.cart_id == cart["id"])
    await database.execute(delete_query)


@cart_router.post("/checkout", response_model=CheckoutResponse, status_code=status.HTTP_201_CREATED)
async def checkout(
    checkout_request: CheckoutRequest,
    current_user: User = Depends(get_current_active_user),
    payment_gateway: PaymentGateway = Depends(get_payment_gateway)
):
    from app.redis_client import WalletLock
    from ..services.connection_manager import manager
    import uuid
    
    idempotency_key = str(uuid.uuid4())
    
    async with WalletLock(current_user["id"], idempotency_key):
        user_dict = dict(current_user)
        cart = await get_or_create_cart(user_dict["id"])
        cart_items = await get_cart_items(cart["id"])
        
        if not cart_items:
            raise APIError.cart_empty()
        
        bar_ids = set(item["bar_id"] for item in cart_items)
        if len(bar_ids) > 1:
            raise APIError.bad_request("All items must be from the same bar")
        
        bar_id = bar_ids.pop()
    
        subtotal = sum(Decimal(str(item["quantity"] * item["unit_price"])) for item in cart_items)
    
        from ..services.discounts import calculate_progressive_discount
        
        progressive_data = await calculate_progressive_discount(user_dict["id"], bar_id)
        progressive_pct = Decimal(str(progressive_data["percentage"]))
        progressive_discount_amount = subtotal * progressive_pct
        
        coupon_discount = Decimal("0.00")
        if checkout_request.coupon_code:
            pass
            
        discount = max(coupon_discount, progressive_discount_amount)
        
        tax_rate = Decimal("0.10")
        tax = subtotal * tax_rate
        
        tip = Decimal(str(checkout_request.tip)) if checkout_request.tip else Decimal("0.00")
        
        delivery_fee = Decimal("0.00")
        if checkout_request.order_type == "delivery":
            delivery_fee = Decimal("5.00")
        
        total = subtotal + tax + tip + delivery_fee - discount
        
        estimated_ready_time = datetime.utcnow() + timedelta(minutes=30)
        
        transaction = await database.transaction()
        await transaction.start()

        
        try:
            order_data = {
                "user_id": user_dict["id"],
                "bar_id": bar_id,
                "status": "pending",
                "order_type": checkout_request.order_type,
                "subtotal": float(subtotal),
                "tax": float(tax),
                "tip": float(tip),
                "delivery_fee": float(delivery_fee),
                "discount": float(discount),
                "total_price": float(total),
                "payment_method": checkout_request.payment_method,
                "payment_status": "pending",
                "estimated_ready_time": estimated_ready_time,
                "delivery_address": checkout_request.delivery_address,
                "special_instructions": checkout_request.special_instructions
            }
            
            order_id = await database.execute(OrderModel.__table__.insert().values(**order_data))
            
            await manager.notify_bar(bar_id, {
                "type": "new_order",
                "order_id": order_id,
                "bar_id": bar_id,
                "status": "pending",
                "total_price": float(total),
                "items_count": len(cart_items),
                "timestamp": datetime.utcnow().isoformat(),
                "message": "🔔 New order received! Awaiting your confirmation"
            })
            
            for cart_item in cart_items:
                order_item_data = {
                    "order_id": order_id,
                    "menu_item_id": cart_item["menu_item_id"],
                    "menu_item_name": cart_item["menu_item_name"],
                    "quantity": cart_item["quantity"],
                    "unit_price": cart_item["unit_price"],
                    "total_price": cart_item["quantity"] * cart_item["unit_price"],
                }
                await database.execute(OrderItemModel.__table__.insert().values(**order_item_data))
            
            payment_result = None
            payment_error = None
            
            try:
                payment_amount = int(total * 100)
                
                payment_result = payment_gateway.create_charge(
                    amount=payment_amount,
                    currency="usd",
                    customer={
                        "email": user_dict.get("email"),
                        "phone": user_dict.get("phone_number"),
                        "name": user_dict.get("name")
                    },
                    payment_method=checkout_request.payment_details or {}
                )
                
                if payment_result.get("status") == "succeeded":
                    update_data = {
                        "payment_status": "completed",
                        "payment_id": payment_result.get("id"),
                        "status": "confirmed"
                    }
                else:
                    update_data = {
                        "payment_status": "failed",
                        "payment_id": payment_result.get("id")
                    }
                    payment_error = payment_result.get("message", "Payment failed")
                
                await database.execute(
                    OrderModel.__table__
                    .update()
                    .where(OrderModel.id == order_id)
                    .values(**update_data)
                )
                
            except Exception as e:
                await database.execute(
                    OrderModel.__table__
                    .update()
                    .where(OrderModel.id == order_id)
                    .values(payment_status="failed")
                )
                payment_error = str(e)
            
            if payment_error:
                # No internal rollback here, let the outer catch blocks handle it
                raise APIError.payment_declined(message=payment_error)
            
            await database.execute(
                CartItemModel.__table__.delete().where(CartItemModel.cart_id == cart["id"])
            )
            
            await transaction.commit()
            
            order = await database.fetch_one(
                OrderModel.__table__.select().where(OrderModel.id == order_id)
            )
            
            try:
                from app.bars_and_restaurants.services.wallet_service import WalletService
                from app.bars_and_restaurants.schemas.wallet import EarnCashbackRequest
                from app.bars_and_restaurants.models.wallet_models import FundingSource
                from app.database import SessionLocal
                
                db = SessionLocal()
                try:
                    cashback_req = EarnCashbackRequest(
                        user_id=current_user["id"],
                        order_id=order_id,
                        bar_id=bar_id,
                        order_total=total,
                        cashback_percentage=Decimal("0.05"),
                        funded_by=FundingSource.BARZ,
                        expires_days=90
                    )
                    
                    WalletService.earn_cashback(db, cashback_req, auto_available=False)
                finally:
                    db.close()
            except Exception as cashback_error:
                print(f"Failed to generate cashback for order {order_id}: {cashback_error}")
            
            return CheckoutResponse(
                order_id=order["id"],
                status=order["status"],
                payment_status=order["payment_status"],
                payment_id=order.get("payment_id"),
                total=order["total_price"],
                estimated_ready_time=order["estimated_ready_time"]
            )
            
        except APIError:
            await transaction.rollback()
            raise
        except Exception as e:
            await transaction.rollback()
            raise APIError.server_error(f"Checkout failed: {str(e)}")

@cart_router.post("/sync", response_model=CartResponse)
async def sync_cart(
    request: CartSyncRequest,
    current_user: User = Depends(get_current_active_user)
):
    """
    Sync cart state: calculates totals, verifies stock/prices, and validates location/promotions.
    This is a server-driven UI endpoint that returns the full view state for the cart.
    """
    from ..services.cart_service import CartService
    from ..models.relational_models import Menu, MenuItem
    from datetime import datetime
    
    response = await CartService.sync_cart(current_user["id"], request)
    
    # Persist the cart state in DB if there are no hard errors
    has_errors = any(issue.severity == "error" for issue in response.validation_issues)
    if not has_errors:
        cart = await get_or_create_cart(current_user["id"])
        
        # Clear existing items
        delete_query = CartItemModel.__table__.delete().where(CartItemModel.cart_id == cart["id"])
        await database.execute(delete_query)
        
        # Insert new items
        if response.items:
            first_item_id = response.items[0].menu_item_id
            query = MenuItem.__table__.select().where(MenuItem.id == first_item_id)
            menu_item_record = await database.fetch_one(query)
            bar_id = None
            if menu_item_record:
                menu_query = Menu.__table__.select().where(Menu.id == menu_item_record["menu_id"])
                menu_record = await database.fetch_one(menu_query)
                if menu_record:
                    bar_id = menu_record["bar_id"]
            
            if bar_id:
                for item in response.items:
                    now = datetime.utcnow()
                    item_data = {
                        "cart_id": cart["id"],
                        "menu_item_id": item.menu_item_id,
                        "menu_item_name": item.name,
                        "bar_id": bar_id,
                        "quantity": item.quantity,
                        "unit_price": item.unit_price,
                        "created_at": now,
                        "updated_at": now
                    }
                    await database.execute(CartItemModel.__table__.insert().values(**item_data))
                    
    return response
