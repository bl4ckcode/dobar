"""
Wallet Service - Business logic for cashback operations
"""
from datetime import datetime, timezone, timedelta
from decimal import Decimal
from typing import Optional, List, Tuple
from uuid import UUID
from sqlalchemy.orm import Session, joinedload
from sqlalchemy import and_, func

from app.bars_and_restaurants.models.wallet_models import (
    CashbackLedger, UserWallet, CashbackType, CashbackStatus, FundingSource
)
from app.bars_and_restaurants.models.relational_models import Bar
from app.bars_and_restaurants.schemas.wallet import (
    EarnCashbackRequest, CashbackTransactionResponse, WalletBalanceResponse,
    CashbackCalculation
)
from app.errors import APIError


class WalletService:
    """Service layer for wallet and cashback operations"""
    
    @staticmethod
    def get_or_create_wallet(db: Session, user_id: int) -> UserWallet:
        """Get user's wallet or create if doesn't exist"""
        wallet = db.query(UserWallet).filter(UserWallet.user_id == user_id).first()
        if not wallet:
            wallet = UserWallet(
                user_id=user_id,
                available_balance=Decimal("0.00"),
                pending_balance=Decimal("0.00")
            )
            db.add(wallet)
            db.commit()
            db.refresh(wallet)
        return wallet
    
    @staticmethod
    def get_wallet_balance(db: Session, user_id: int) -> WalletBalanceResponse:
        """Get user's current wallet balance"""
        wallet = WalletService.get_or_create_wallet(db, user_id)
        return WalletBalanceResponse(
            user_id=wallet.user_id,
            available_balance=wallet.available_balance,
            pending_balance=wallet.pending_balance,
            total_balance=wallet.total_balance,
            last_updated=wallet.last_updated or datetime.now(timezone.utc)
        )
    
    @staticmethod
    def calculate_cashback(
        order_total: Decimal,
        cashback_percentage: Decimal,
        funded_by: FundingSource = FundingSource.BARZ,
        expires_days: Optional[int] = None
    ) -> CashbackCalculation:
        """Calculate cashback amount and expiry"""
        cashback_amount = round(order_total * cashback_percentage, 2)
        
        expires_at = None
        if expires_days is not None:
            expires_at = datetime.now(timezone.utc) + timedelta(days=expires_days)
        
        return CashbackCalculation(
            order_total=order_total,
            cashback_percentage=cashback_percentage,
            cashback_amount=cashback_amount,
            funded_by=funded_by,
            expires_at=expires_at
        )
    
    @staticmethod
    def earn_cashback(
        db: Session,
        request: EarnCashbackRequest,
        auto_available: bool = False
    ) -> Tuple[CashbackLedger, UserWallet]:
        """
        Create cashback earning transaction.
        
        Args:
            db: Database session
            request: Earn cashback request
            auto_available: If True, make cashback immediately available (skip pending)
        
        Returns:
            Tuple of (created transaction, updated wallet)
        """
        # Calculate cashback
        calculation = WalletService.calculate_cashback(
            order_total=request.order_total,
            cashback_percentage=request.cashback_percentage,
            funded_by=request.funded_by,
            expires_days=request.expires_days
        )
        
        # Create ledger entry
        transaction = CashbackLedger(
            user_id=request.user_id,
            order_id=request.order_id,
            bar_id=request.bar_id,
            amount=calculation.cashback_amount,
            type=CashbackType.EARN,
            funded_by=request.funded_by,
            status=CashbackStatus.AVAILABLE if auto_available else CashbackStatus.PENDING,
            created_at=datetime.now(timezone.utc),
            expires_at=calculation.expires_at
        )
        db.add(transaction)
        
        # Update wallet balance
        wallet = WalletService.get_or_create_wallet(db, request.user_id)
        if auto_available:
            wallet.available_balance += calculation.cashback_amount
        else:
            wallet.pending_balance += calculation.cashback_amount
        
        wallet.last_updated = datetime.now(timezone.utc)
        
        db.commit()
        db.refresh(transaction)
        db.refresh(wallet)
        
        return transaction, wallet
    
    @staticmethod
    def make_cashback_available(db: Session, transaction_id: UUID) -> CashbackLedger:
        """
        Move cashback from PENDING to AVAILABLE status.
        Typically called after refund period expires.
        """
        transaction = db.query(CashbackLedger).filter(
            CashbackLedger.id == transaction_id,
            CashbackLedger.status == CashbackStatus.PENDING
        ).first()
        
        if not transaction:
            raise APIError.not_found("Pending cashback transaction not found")
        
        # Update transaction status
        transaction.status = CashbackStatus.AVAILABLE
        
        # Move balance from pending to available
        wallet = WalletService.get_or_create_wallet(db, transaction.user_id)
        wallet.pending_balance -= transaction.amount
        wallet.available_balance += transaction.amount
        wallet.last_updated = datetime.now(timezone.utc)
        
        db.commit()
        db.refresh(transaction)
        
        return transaction
    
    @staticmethod
    def redeem_cashback(
        db: Session,
        user_id: int,
        amount: Decimal,
        bar_id: int,
        order_id: Optional[int] = None
    ) -> Tuple[CashbackLedger, UserWallet]:
        """
        Redeem cashback from wallet.
        
        Args:
            db: Database session
            user_id: User redeeming cashback
            amount: Amount to redeem
            bar_id: Bar where cashback is being used
            order_id: Optional order ID
        
        Returns:
            Tuple of (redemption transaction, updated wallet)
        
        Raises:
            HTTPException: If insufficient balance
        """
        wallet = WalletService.get_or_create_wallet(db, user_id)
        
        # Check sufficient balance
        if wallet.available_balance < amount:
            raise APIError.insufficient_funds(
                message=f"Insufficient wallet balance. Requested: ${float(amount):.2f}, Available: ${float(wallet.available_balance):.2f}"
            )
        
        # Create redemption transaction (negative amount)
        transaction = CashbackLedger(
            user_id=user_id,
            order_id=order_id,
            bar_id=bar_id,
            amount=-amount,  # Negative for redemption
            type=CashbackType.REDEEM,
            funded_by=FundingSource.BARZ,  # Not really applicable for redemption
            status=CashbackStatus.USED,
            created_at=datetime.now(timezone.utc)
        )
        db.add(transaction)
        
        # Deduct from wallet
        wallet.available_balance -= amount
        wallet.last_updated = datetime.now(timezone.utc)
        
        db.commit()
        db.refresh(transaction)
        db.refresh(wallet)
        
        return transaction, wallet
    
    @staticmethod
    def expire_cashback(db: Session, transaction_id: UUID) -> CashbackLedger:
        """
        Mark cashback as expired and remove from balance.
        Called by scheduled job to process expired cashback.
        """
        transaction = db.query(CashbackLedger).filter(
            CashbackLedger.id == transaction_id,
            CashbackLedger.status.in_([CashbackStatus.PENDING, CashbackStatus.AVAILABLE])
        ).first()
        
        if not transaction:
            raise APIError.not_found("Active cashback transaction not found")
        
        # Update transaction status
        old_status = transaction.status
        transaction.status = CashbackStatus.EXPIRED
        
        # Remove from wallet balance
        wallet = WalletService.get_or_create_wallet(db, transaction.user_id)
        if old_status == CashbackStatus.AVAILABLE:
            wallet.available_balance -= transaction.amount
        elif old_status == CashbackStatus.PENDING:
            wallet.pending_balance -= transaction.amount
        
        wallet.last_updated = datetime.now(timezone.utc)
        
        db.commit()
        db.refresh(transaction)
        
        return transaction
    
    @staticmethod
    def process_expirations(db: Session) -> int:
        """
        Process all expired cashback transactions.
        Should be called by scheduled job.
        
        Returns:
            Number of transactions expired
        """
        now = datetime.now(timezone.utc)
        
        expired_transactions = db.query(CashbackLedger).filter(
            and_(
                CashbackLedger.expires_at <= now,
                CashbackLedger.expires_at.isnot(None),
                CashbackLedger.status.in_([CashbackStatus.PENDING, CashbackStatus.AVAILABLE])
            )
        ).all()
        
        count = 0
        for transaction in expired_transactions:
            try:
                WalletService.expire_cashback(db, transaction.id)
                count += 1
            except Exception as e:
                # Log error but continue processing others
                print(f"Error expiring transaction {transaction.id}: {e}")
                continue
        
        return count
    
    @staticmethod
    def get_transaction_history(
        db: Session,
        user_id: int,
        page: int = 1,
        page_size: int = 20,
        transaction_type: Optional[CashbackType] = None,
        status_filter: Optional[CashbackStatus] = None
    ) -> Tuple[List[CashbackTransactionResponse], int]:
        """
        Get user's cashback transaction history with pagination.
        
        Returns:
            Tuple of (transactions list, total count)
        """
        query = db.query(CashbackLedger).filter(CashbackLedger.user_id == user_id)
        
        # Apply filters
        if transaction_type:
            query = query.filter(CashbackLedger.type == transaction_type)
        if status_filter:
            query = query.filter(CashbackLedger.status == status_filter)
        
        # Get total count
        total_count = query.count()
        
        # Apply pagination
        offset = (page - 1) * page_size
        transactions = query.order_by(CashbackLedger.created_at.desc()).offset(offset).limit(page_size).all()
        
        # Convert to response with bar names
        response_list = []
        for txn in transactions:
            bar = db.query(Bar).filter(Bar.id == txn.bar_id).first()
            response_list.append(CashbackTransactionResponse(
                id=txn.id,
                user_id=txn.user_id,
                order_id=txn.order_id,
                bar_id=txn.bar_id,
                bar_name=bar.name if bar else None,
                amount=txn.amount,
                type=txn.type,
                funded_by=txn.funded_by,
                status=txn.status,
                created_at=txn.created_at,
                expires_at=txn.expires_at
            ))
        
        return response_list, total_count
    
    @staticmethod
    def adjust_balance(
        db: Session,
        user_id: int,
        amount: Decimal,
        bar_id: int,
        reason: str = "Manual adjustment"
    ) -> Tuple[CashbackLedger, UserWallet]:
        """
        Manual adjustment of wallet balance (admin operation).
        Positive amount = credit, negative = debit.
        """
        transaction = CashbackLedger(
            user_id=user_id,
            bar_id=bar_id,
            amount=amount,
            type=CashbackType.ADJUST,
            funded_by=FundingSource.BARZ,
            status=CashbackStatus.AVAILABLE,
            created_at=datetime.now(timezone.utc)
        )
        db.add(transaction)
        
        wallet = WalletService.get_or_create_wallet(db, user_id)
        wallet.available_balance += amount
        wallet.last_updated = datetime.now(timezone.utc)
        
        db.commit()
        db.refresh(transaction)
        db.refresh(wallet)
        
        return transaction, wallet
    
    @staticmethod
    def get_or_create_bar_wallet(db: Session, bar_id: int):
        from app.bars_and_restaurants.models.wallet_models import BarWallet
        
        wallet = db.query(BarWallet).filter(BarWallet.bar_id == bar_id).first()
        if not wallet:
            wallet = BarWallet(
                bar_id=bar_id,
                available_balance=Decimal("0.00"),
                reserved_balance=Decimal("0.00")
            )
            db.add(wallet)
            db.commit()
            db.refresh(wallet)
        return wallet
    
    @staticmethod
    def get_bar_wallet_balance(db: Session, bar_id: int) -> dict:
        wallet = WalletService.get_or_create_bar_wallet(db, bar_id)
        return {
            "bar_id": wallet.bar_id,
            "available_balance": wallet.available_balance,
            "reserved_balance": wallet.reserved_balance,
            "total_balance": wallet.total_balance,
            "last_updated": wallet.last_updated or datetime.now(timezone.utc)
        }
    
    @staticmethod
    def validate_promotion_funding(db: Session, bar_id: int, amount: Decimal, funded_by: FundingSource) -> bool:
        if funded_by == FundingSource.BARZ:
            return True
        
        if funded_by == FundingSource.BAR:
            wallet = WalletService.get_or_create_bar_wallet(db, bar_id)
            return wallet.available_balance >= amount
        
        return False
    
    @staticmethod
    def reserve_bar_funds(db: Session, bar_id: int, amount: Decimal) -> bool:
        from app.bars_and_restaurants.models.wallet_models import BarWallet
        
        wallet = WalletService.get_or_create_bar_wallet(db, bar_id)
        
        if wallet.available_balance < amount:
            return False
        
        wallet.available_balance -= amount
        wallet.reserved_balance += amount
        wallet.last_updated = datetime.now(timezone.utc)
        
        db.commit()
        db.refresh(wallet)
        return True
    
    @staticmethod
    def release_bar_funds(db: Session, bar_id: int, amount: Decimal):
        from app.bars_and_restaurants.models.wallet_models import BarWallet
        
        wallet = WalletService.get_or_create_bar_wallet(db, bar_id)
        wallet.reserved_balance -= amount
        wallet.available_balance += amount
        wallet.last_updated = datetime.now(timezone.utc)
        
        db.commit()
        db.refresh(wallet)
