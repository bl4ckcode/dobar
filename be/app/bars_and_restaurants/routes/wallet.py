from fastapi import APIRouter, Depends, status, Query
from sqlalchemy.orm import Session
from typing import Optional
from decimal import Decimal

from app.database import get_db
from app.auth.middleware import get_current_user
from app.auth.auth_models import User
from app.auth.admin import require_internal_or_admin, verify_admin_api_key
from app.errors import APIError
from app.bars_and_restaurants.services.wallet_service import WalletService
from app.bars_and_restaurants.schemas.wallet import (
    WalletBalanceResponse,
    WalletHistoryResponse,
    EarnCashbackRequest,
    RedeemCashbackRequest,
    ApplyCashbackRequest,
    CashbackEarnedResponse,
    CashbackAppliedResponse,
    CashbackTransactionResponse,
)
from app.bars_and_restaurants.models.wallet_models import CashbackType, CashbackStatus


wallet_router = APIRouter(prefix="/wallet", tags=["Wallet & Cashback"])


@wallet_router.get("/", response_model=WalletBalanceResponse)
async def get_wallet_balance(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get current user's wallet balance.
    Returns available, pending, and total balance.
    """
    return WalletService.get_wallet_balance(db, current_user.id)


@wallet_router.get("/history", response_model=WalletHistoryResponse)
async def get_wallet_history(
    page: int = Query(1, ge=1, description="Page number"),
    page_size: int = Query(20, ge=1, le=100, description="Items per page"),
    transaction_type: Optional[CashbackType] = Query(None, description="Filter by transaction type"),
    status_filter: Optional[CashbackStatus] = Query(None, description="Filter by status"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get user's cashback transaction history with pagination and filters.
    """
    transactions, total_count = WalletService.get_transaction_history(
        db=db,
        user_id=current_user.id,
        page=page,
        page_size=page_size,
        transaction_type=transaction_type,
        status_filter=status_filter
    )
    
    has_next = (page * page_size) < total_count
    
    return WalletHistoryResponse(
        transactions=transactions,
        total_count=total_count,
        page=page,
        page_size=page_size,
        has_next=has_next
    )


@wallet_router.post("/earn", response_model=CashbackEarnedResponse)
async def earn_cashback(
    request: EarnCashbackRequest,
    db: Session = Depends(get_db),
    _internal: bool = Depends(require_internal_or_admin)
):
    transaction, wallet = WalletService.earn_cashback(
        db=db,
        request=request,
        auto_available=False
    )
    
    status_message = (
        "Cashback earned! It will be available after the refund period."
        if transaction.status == CashbackStatus.PENDING
        else "Cashback earned and immediately available!"
    )
    
    return CashbackEarnedResponse(
        transaction_id=transaction.id,
        amount_earned=transaction.amount,
        new_balance=wallet.total_balance,
        status=transaction.status,
        expires_at=transaction.expires_at,
        message=status_message
    )


@wallet_router.post("/apply", response_model=CashbackAppliedResponse)
async def apply_cashback_to_order(
    request: ApplyCashbackRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Apply cashback credit to current checkout.
    Returns the amount applied and remaining balance.
    
    If amount is not specified, applies all available balance.
    """
    wallet = WalletService.get_or_create_wallet(db, current_user.id)
    
    # Determine amount to apply
    amount_to_apply = request.amount if request.amount else wallet.available_balance
    
    # Validate sufficient balance
    if amount_to_apply > wallet.available_balance:
        raise APIError.insufficient_funds(
            message=f"Insufficient wallet balance. Requested: ${float(amount_to_apply):.2f}, Available: ${float(wallet.available_balance):.2f}"
        )
    
    if amount_to_apply <= 0:
        raise APIError.bad_request("No cashback available to apply")
    
    # Note: The actual redemption happens when order is placed
    # This endpoint just validates and returns the discount to be applied
    
    return CashbackAppliedResponse(
        amount_applied=amount_to_apply,
        remaining_balance=wallet.available_balance - amount_to_apply,
        discount_code=f"CASHBACK_{current_user.id}_{int(amount_to_apply * 100)}",
        message=f"${amount_to_apply:.2f} cashback will be applied to your order"
    )


@wallet_router.post("/redeem")
async def redeem_cashback_for_order(
    request: RedeemCashbackRequest,
    bar_id: int = Query(..., description="Bar where cashback is being used"),
    order_id: Optional[int] = Query(None, description="Order ID if already created"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Actually redeem cashback from wallet.
    This is typically called during order creation/checkout.
    
    Creates a REDEEM transaction and deducts from available balance.
    """
    transaction, wallet = WalletService.redeem_cashback(
        db=db,
        user_id=current_user.id,
        amount=request.amount,
        bar_id=bar_id,
        order_id=order_id
    )
    
    return {
        "transaction_id": str(transaction.id),
        "amount_redeemed": abs(float(transaction.amount)),
        "remaining_balance": float(wallet.available_balance),
        "message": f"Successfully redeemed ${abs(transaction.amount):.2f} cashback"
    }


# ============== Admin/Internal Endpoints ==============

@wallet_router.post("/admin/make-available/{transaction_id}")
async def make_cashback_available(
    transaction_id: str,
    db: Session = Depends(get_db),
    _admin: bool = Depends(require_internal_or_admin)
):
    from uuid import UUID
    
    try:
        transaction_uuid = UUID(transaction_id)
    except ValueError:
        raise APIError.validation_error(
            message="Invalid transaction ID format",
            details={"transaction_id": ["Must be a valid UUID"]}
        )
    
    transaction = WalletService.make_cashback_available(db, transaction_uuid)
    
    return {
        "transaction_id": str(transaction.id),
        "user_id": transaction.user_id,
        "amount": float(transaction.amount),
        "status": transaction.status.value,
        "message": "Cashback is now available for use"
    }


@wallet_router.post("/admin/expire/{transaction_id}")
async def expire_cashback_transaction(
    transaction_id: str,
    db: Session = Depends(get_db),
    _admin: bool = Depends(require_internal_or_admin)
):
    from uuid import UUID
    
    try:
        transaction_uuid = UUID(transaction_id)
    except ValueError:
        raise APIError.validation_error(
            message="Invalid transaction ID format",
            details={"transaction_id": ["Must be a valid UUID"]}
        )
    
    transaction = WalletService.expire_cashback(db, transaction_uuid)
    
    return {
        "transaction_id": str(transaction.id),
        "user_id": transaction.user_id,
        "amount": float(transaction.amount),
        "status": transaction.status.value,
        "message": "Cashback expired and removed from balance"
    }


@wallet_router.post("/admin/process-expirations")
async def process_expired_cashback(
    db: Session = Depends(get_db),
    _admin: bool = Depends(require_internal_or_admin)
):
    count = WalletService.process_expirations(db)
    
    return {
        "expired_count": count,
        "message": f"Processed {count} expired cashback transactions"
    }


@wallet_router.post("/admin/adjust")
async def adjust_wallet_balance(
    user_id: int,
    amount: Decimal,
    bar_id: int,
    reason: str = "Manual adjustment",
    db: Session = Depends(get_db),
    _admin: bool = Depends(verify_admin_api_key)
):
    transaction, wallet = WalletService.adjust_balance(
        db=db,
        user_id=user_id,
        amount=amount,
        bar_id=bar_id,
        reason=reason
    )
    
    return {
        "transaction_id": str(transaction.id),
        "user_id": user_id,
        "amount_adjusted": float(amount),
        "new_balance": float(wallet.available_balance),
        "reason": reason,
        "message": f"Wallet adjusted by ${amount:.2f}"
    }
