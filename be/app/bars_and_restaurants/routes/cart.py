"""
Cart management routes.
"""

from fastapi import APIRouter, HTTPException, Depends, status
from sqlalchemy import and_
from typing import List, Optional
from decimal import Decimal
from datetime import datetime, timedelta, timezone

from app.auth.middleware import get_current_active_user
from app.auth.auth_models import User
from ..models.cart_models import Cart as CartModel, CartItem as CartItemModel, OrderItem as OrderItemModel
from ..models.relational_models import Order as OrderModel
from ..schemas.cart import Cart, CartItem, CartItemCreate, CartItemUpdate, CheckoutRequest, CheckoutResponse
from app.database import database
from app.payment.core.factory import get_payment_gateway
from app.payment.core.interfaces import PaymentGateway

cart_router = APIRouter(prefix="/cart", tags=["Cart"])


async def get_or_create_cart(user_id: int) -> CartModel:
    """Get or create a cart for the user."""
    # Check if cart exists
    query = CartModel.__table__.select().where(CartModel.user_id == user_id)
    cart = await database.fetch_one(query)
    
    if not cart:
        # Create new cart
        cart_data = {"user_id": user_id}
        cart_id = await database.execute(CartModel.__table__.insert().values(**cart_data))
        cart = await database.fetch_one(CartModel.__table__.select().where(CartModel.id == cart_id))
    
    return cart


async def get_cart_items(cart_id: int) -> List[CartItemModel]:
    """Get all items in a cart."""
    query = CartItemModel.__table__.select().where(CartItemModel.cart_id == cart_id)
    return await database.fetch_all(query)


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
    """Get the current user's cart with all items."""
    cart = await get_or_create_cart(current_user["id"])
    items = await get_cart_items(cart["id"])
    totals = await calculate_cart_totals(cart["id"])
    
    return {
        **dict(cart),
        "items": items,
        **totals
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
        # Update quantity
        new_quantity = existing_item["quantity"] + item.quantity
        update_query = (
            CartItemModel.__table__
            .update()
            .where(CartItemModel.id == existing_item["id"])
            .values(quantity=new_quantity)
        )
        await database.execute(update_query)
        
        # Fetch updated item
        return await database.fetch_one(
            CartItemModel.__table__.select().where(CartItemModel.id == existing_item["id"])
        )
    else:
        # Add new item
        item_data = {
            **item.model_dump(),
            "cart_id": cart["id"]
        }
        item_id = await database.execute(CartItemModel.__table__.insert().values(**item_data))
        return await database.fetch_one(
            CartItemModel.__table__.select().where(CartItemModel.id == item_id)
        )


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
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Cart item not found"
        )
    
    # Update quantity
    update_query = (
        CartItemModel.__table__
        .update()
        .where(CartItemModel.id == item_id)
        .values(quantity=item_update.quantity)
    )
    await database.execute(update_query)
    
    return await database.fetch_one(
        CartItemModel.__table__.select().where(CartItemModel.id == item_id)
    )


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
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Cart item not found"
        )
    
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
    """
    Checkout the cart and create an order.
    
    Process:
    1. Validate cart is not empty
    2. Validate all items from same bar
    3. Calculate totals (subtotal + tax + tip + delivery_fee - discount)
    4. Create order with order items in transaction
    5. Process payment via payment gateway
    6. Update order with payment status
    7. Clear cart if successful
    8. Trigger WebSocket notification (TODO)
    """
    # Get cart and items
    cart = await get_or_create_cart(current_user["id"])
    cart_items = await get_cart_items(cart["id"])
    
    if not cart_items:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cart is empty"
        )
    
    # Validate all items from same bar
    bar_ids = set(item["bar_id"] for item in cart_items)
    if len(bar_ids) > 1:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="All items must be from the same bar"
        )
    
    bar_id = bar_ids.pop()
    
    # Calculate totals
    subtotal = sum(Decimal(str(item["quantity"] * item["unit_price"])) for item in cart_items)
    
    # Apply discount if coupon provided
    discount = Decimal("0.00")
    if checkout_request.coupon_code:
        # TODO: Implement coupon validation and discount calculation
        pass
    
    # Calculate tax (assuming 10% tax rate - should come from bar/location settings)
    tax_rate = Decimal("0.10")
    tax = subtotal * tax_rate
    
    # Get tip
    tip = Decimal(str(checkout_request.tip)) if checkout_request.tip else Decimal("0.00")
    
    # Calculate delivery fee (should come from bar settings)
    delivery_fee = Decimal("0.00")
    if checkout_request.order_type == "delivery":
        delivery_fee = Decimal("5.00")  # TODO: Get from bar settings
    
    # Calculate total
    total = subtotal + tax + tip + delivery_fee - discount
    
    # Estimate ready time (30 minutes from now - should be based on bar settings)
    estimated_ready_time = datetime.now(timezone.utc) + timedelta(minutes=30)
    
    # Start transaction to create order
    transaction = await database.transaction()
    
    try:
        # Create order
        order_data = {
            "user_id": current_user["id"],
            "bar_id": bar_id,
            "status": "pending",
            "order_type": checkout_request.order_type,
            "subtotal": float(subtotal),
            "tax": float(tax),
            "tip": float(tip),
            "delivery_fee": float(delivery_fee),
            "discount": float(discount),
            "total": float(total),
            "payment_method": checkout_request.payment_method,
            "payment_status": "pending",
            "estimated_ready_time": estimated_ready_time,
            "delivery_address": checkout_request.delivery_address,
            "special_instructions": checkout_request.special_instructions
        }
        
        order_id = await database.execute(OrderModel.__table__.insert().values(**order_data))
        
        # Create order items from cart items
        for cart_item in cart_items:
            order_item_data = {
                "order_id": order_id,
                "menu_item_id": cart_item["menu_item_id"],
                "menu_item_name": cart_item["menu_item_name"],
                "quantity": cart_item["quantity"],
                "unit_price": cart_item["unit_price"],
                "subtotal": cart_item["quantity"] * cart_item["unit_price"],
                "special_instructions": cart_item.get("special_instructions")
            }
            await database.execute(OrderItemModel.__table__.insert().values(**order_item_data))
        
        # Process payment
        payment_result = None
        payment_error = None
        
        try:
            # Prepare payment data
            payment_amount = int(total * 100)  # Convert to cents
            
            payment_result = payment_gateway.create_charge(
                amount=payment_amount,
                currency="usd",
                customer={
                    "email": current_user.get("email"),
                    "phone": current_user.get("phone_number"),
                    "name": current_user.get("name")
                },
                payment_method=checkout_request.payment_details or {}
            )
            
            # Update order with payment info
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
            # Update order with payment failure
            await database.execute(
                OrderModel.__table__
                .update()
                .where(OrderModel.id == order_id)
                .values(payment_status="failed")
            )
            payment_error = str(e)
        
        # If payment failed, rollback and raise error
        if payment_error:
            await transaction.rollback()
            raise HTTPException(
                status_code=status.HTTP_402_PAYMENT_REQUIRED,
                detail=payment_error
            )
        
        # Clear cart
        await database.execute(
            CartItemModel.__table__.delete().where(CartItemModel.cart_id == cart["id"])
        )
        
        # Commit transaction
        await transaction.commit()
        
        # Fetch the created order
        order = await database.fetch_one(
            OrderModel.__table__.select().where(OrderModel.id == order_id)
        )
        
        # TODO: Trigger WebSocket notification for real-time updates
        
        return CheckoutResponse(
            order_id=order["id"],
            status=order["status"],
            payment_status=order["payment_status"],
            payment_id=order.get("payment_id"),
            total=order["total"],
            estimated_ready_time=order["estimated_ready_time"]
        )
        
    except HTTPException:
        await transaction.rollback()
        raise
    except Exception as e:
        await transaction.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Checkout failed: {str(e)}"
        )
