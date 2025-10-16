"""
Comprehensive tests for wallet and cashback functionality.
"""

import pytest
from datetime import datetime, timedelta, timezone
from decimal import Decimal
from uuid import uuid4

from app.bars_and_restaurants.models.wallet_models import (
    CashbackLedger, UserWallet, CashbackType, CashbackStatus, FundingSource
)
from app.bars_and_restaurants.services.wallet_service import WalletService
from app.bars_and_restaurants.schemas.wallet import EarnCashbackRequest
from app.auth.auth_models import User
from app.bars_and_restaurants.models.relational_models import Bar, Order
from fastapi import HTTPException


class TestWalletCreation:
    """Test wallet creation and retrieval."""
    
    def test_get_or_create_wallet_new_user(self, db_session, test_user, test_bar):
        """Test creating wallet for new user."""
        wallet = WalletService.get_or_create_wallet(db_session, test_user.id)
        
        assert wallet is not None
        assert wallet.user_id == test_user.id
        assert wallet.available_balance == Decimal("0.00")
        assert wallet.pending_balance == Decimal("0.00")
        assert wallet.total_balance == Decimal("0.00")
    
    def test_get_or_create_wallet_existing_user(self, db_session, test_user):
        """Test getting existing wallet."""
        # Create wallet first
        wallet1 = WalletService.get_or_create_wallet(db_session, test_user.id)
        wallet1.available_balance = Decimal("10.00")
        db_session.commit()
        
        # Get wallet again
        wallet2 = WalletService.get_or_create_wallet(db_session, test_user.id)
        
        assert wallet2.user_id == wallet1.user_id
        assert wallet2.available_balance == Decimal("10.00")
    
    def test_get_wallet_balance(self, db_session, test_user):
        """Test getting wallet balance response."""
        wallet = WalletService.get_or_create_wallet(db_session, test_user.id)
        wallet.available_balance = Decimal("25.50")
        wallet.pending_balance = Decimal("5.00")
        db_session.commit()
        
        response = WalletService.get_wallet_balance(db_session, test_user.id)
        
        assert response.user_id == test_user.id
        assert response.available_balance == Decimal("25.50")
        assert response.pending_balance == Decimal("5.00")
        assert response.total_balance == Decimal("30.50")


class TestCashbackCalculation:
    """Test cashback calculation logic."""
    
    def test_calculate_cashback_5_percent(self):
        """Test 5% cashback calculation."""
        calculation = WalletService.calculate_cashback(
            order_total=Decimal("100.00"),
            cashback_percentage=Decimal("0.05"),
            funded_by=FundingSource.BARZ
        )
        
        assert calculation.cashback_amount == Decimal("5.00")
        assert calculation.funded_by == FundingSource.BARZ
        assert calculation.expires_at is None
    
    def test_calculate_cashback_10_percent(self):
        """Test 10% cashback calculation."""
        calculation = WalletService.calculate_cashback(
            order_total=Decimal("50.00"),
            cashback_percentage=Decimal("0.10"),
            funded_by=FundingSource.BAR
        )
        
        assert calculation.cashback_amount == Decimal("5.00")
        assert calculation.funded_by == FundingSource.BAR
    
    def test_calculate_cashback_with_expiry(self):
        """Test cashback calculation with expiry date."""
        calculation = WalletService.calculate_cashback(
            order_total=Decimal("200.00"),
            cashback_percentage=Decimal("0.05"),
            funded_by=FundingSource.BARZ,
            expires_days=30
        )
        
        assert calculation.cashback_amount == Decimal("10.00")
        assert calculation.expires_at is not None
        # Check expiry is approximately 30 days from now
        expected_expiry = datetime.now(timezone.utc) + timedelta(days=30)
        assert abs((calculation.expires_at - expected_expiry).total_seconds()) < 10
    
    def test_calculate_cashback_rounding(self):
        """Test cashback amount is rounded to 2 decimal places."""
        calculation = WalletService.calculate_cashback(
            order_total=Decimal("33.33"),
            cashback_percentage=Decimal("0.05"),
            funded_by=FundingSource.BARZ
        )
        
        # 33.33 * 0.05 = 1.6665, should round to 1.67
        assert calculation.cashback_amount == Decimal("1.67")


class TestEarnCashback:
    """Test earning cashback functionality."""
    
    def test_earn_cashback_pending_status(self, db_session, test_user, test_bar, test_order):
        """Test earning cashback with PENDING status."""
        request = EarnCashbackRequest(
            user_id=test_user.id,
            order_id=test_order.id,
            bar_id=test_bar.id,
            order_total=Decimal("100.00"),
            cashback_percentage=Decimal("0.05"),
            funded_by=FundingSource.BARZ
        )
        
        transaction, wallet = WalletService.earn_cashback(db_session, request, auto_available=False)
        
        assert transaction.amount == Decimal("5.00")
        assert transaction.type == CashbackType.EARN
        assert transaction.status == CashbackStatus.PENDING
        assert transaction.user_id == test_user.id
        assert transaction.order_id == test_order.id
        assert transaction.bar_id == test_bar.id
        assert transaction.funded_by == FundingSource.BARZ
        
        assert wallet.pending_balance == Decimal("5.00")
        assert wallet.available_balance == Decimal("0.00")
    
    def test_earn_cashback_immediately_available(self, db_session, test_user, test_bar, test_order):
        """Test earning cashback that's immediately available."""
        request = EarnCashbackRequest(
            user_id=test_user.id,
            order_id=test_order.id,
            bar_id=test_bar.id,
            order_total=Decimal("50.00"),
            cashback_percentage=Decimal("0.10"),
            funded_by=FundingSource.BAR
        )
        
        transaction, wallet = WalletService.earn_cashback(db_session, request, auto_available=True)
        
        assert transaction.amount == Decimal("5.00")
        assert transaction.status == CashbackStatus.AVAILABLE
        
        assert wallet.available_balance == Decimal("5.00")
        assert wallet.pending_balance == Decimal("0.00")
    
    def test_earn_cashback_with_expiry(self, db_session, test_user, test_bar, test_order):
        """Test earning cashback with expiration date."""
        request = EarnCashbackRequest(
            user_id=test_user.id,
            order_id=test_order.id,
            bar_id=test_bar.id,
            order_total=Decimal("100.00"),
            cashback_percentage=Decimal("0.05"),
            funded_by=FundingSource.BARZ,
            expires_days=90
        )
        
        transaction, wallet = WalletService.earn_cashback(db_session, request)
        
        assert transaction.expires_at is not None
        expected_expiry = datetime.now(timezone.utc) + timedelta(days=90)
        assert abs((transaction.expires_at - expected_expiry).total_seconds()) < 10
    
    def test_earn_multiple_cashback_accumulates(self, db_session, test_user, test_bar, test_order):
        """Test multiple cashback earnings accumulate in wallet."""
        # First cashback
        request1 = EarnCashbackRequest(
            user_id=test_user.id,
            order_id=test_order.id,
            bar_id=test_bar.id,
            order_total=Decimal("100.00"),
            cashback_percentage=Decimal("0.05"),
            funded_by=FundingSource.BARZ
        )
        _, wallet1 = WalletService.earn_cashback(db_session, request1, auto_available=True)
        assert wallet1.available_balance == Decimal("5.00")
        
        # Second cashback
        request2 = EarnCashbackRequest(
            user_id=test_user.id,
            order_id=test_order.id,
            bar_id=test_bar.id,
            order_total=Decimal("60.00"),
            cashback_percentage=Decimal("0.05"),
            funded_by=FundingSource.BAR
        )
        _, wallet2 = WalletService.earn_cashback(db_session, request2, auto_available=True)
        
        # Balance should accumulate
        assert wallet2.available_balance == Decimal("8.00")  # 5.00 + 3.00


class TestMakeCashbackAvailable:
    """Test moving cashback from PENDING to AVAILABLE."""
    
    def test_make_pending_cashback_available(self, db_session, test_user, test_bar, test_order):
        """Test making pending cashback available."""
        # Create pending cashback
        request = EarnCashbackRequest(
            user_id=test_user.id,
            order_id=test_order.id,
            bar_id=test_bar.id,
            order_total=Decimal("100.00"),
            cashback_percentage=Decimal("0.05"),
            funded_by=FundingSource.BARZ
        )
        transaction, _ = WalletService.earn_cashback(db_session, request, auto_available=False)
        
        # Make it available
        updated_transaction = WalletService.make_cashback_available(db_session, transaction.id)
        
        assert updated_transaction.status == CashbackStatus.AVAILABLE
        
        # Check wallet balances updated
        wallet = WalletService.get_or_create_wallet(db_session, test_user.id)
        assert wallet.available_balance == Decimal("5.00")
        assert wallet.pending_balance == Decimal("0.00")
    
    def test_make_non_existent_transaction_available_fails(self, db_session):
        """Test making non-existent transaction available fails."""
        fake_id = uuid4()
        
        with pytest.raises(HTTPException) as exc_info:
            WalletService.make_cashback_available(db_session, fake_id)
        
        assert exc_info.value.status_code == 404


class TestRedeemCashback:
    """Test redeeming cashback from wallet."""
    
    def test_redeem_cashback_sufficient_balance(self, db_session, test_user, test_bar, test_order):
        """Test redeeming cashback with sufficient balance."""
        # First earn some cashback
        request = EarnCashbackRequest(
            user_id=test_user.id,
            order_id=test_order.id,
            bar_id=test_bar.id,
            order_total=Decimal("100.00"),
            cashback_percentage=Decimal("0.05"),
            funded_by=FundingSource.BARZ
        )
        WalletService.earn_cashback(db_session, request, auto_available=True)
        
        # Redeem part of it
        transaction, wallet = WalletService.redeem_cashback(
            db_session, test_user.id, Decimal("3.00"), test_bar.id
        )
        
        assert transaction.amount == Decimal("-3.00")  # Negative for redemption
        assert transaction.type == CashbackType.REDEEM
        assert transaction.status == CashbackStatus.USED
        
        assert wallet.available_balance == Decimal("2.00")  # 5.00 - 3.00
    
    def test_redeem_cashback_insufficient_balance(self, db_session, test_user, test_bar, test_order):
        """Test redeeming more cashback than available fails."""
        # Earn small amount
        request = EarnCashbackRequest(
            user_id=test_user.id,
            order_id=test_order.id,
            bar_id=test_bar.id,
            order_total=Decimal("20.00"),
            cashback_percentage=Decimal("0.05"),
            funded_by=FundingSource.BARZ
        )
        WalletService.earn_cashback(db_session, request, auto_available=True)
        
        # Try to redeem more than available
        with pytest.raises(HTTPException) as exc_info:
            WalletService.redeem_cashback(
                db_session, test_user.id, Decimal("10.00"), test_bar.id
            )
        
        assert exc_info.value.status_code == 400
        assert "insufficient_balance" in str(exc_info.value.detail)
    
    def test_redeem_all_available_balance(self, db_session, test_user, test_bar, test_order):
        """Test redeeming entire available balance."""
        # Earn cashback
        request = EarnCashbackRequest(
            user_id=test_user.id,
            order_id=test_order.id,
            bar_id=test_bar.id,
            order_total=Decimal("100.00"),
            cashback_percentage=Decimal("0.05"),
            funded_by=FundingSource.BARZ
        )
        WalletService.earn_cashback(db_session, request, auto_available=True)
        
        # Redeem all
        transaction, wallet = WalletService.redeem_cashback(
            db_session, test_user.id, Decimal("5.00"), test_bar.id
        )
        
        assert wallet.available_balance == Decimal("0.00")
    
    def test_redeem_cashback_empty_wallet(self, db_session, test_user, test_bar):
        """Test redeeming from empty wallet fails."""
        with pytest.raises(HTTPException) as exc_info:
            WalletService.redeem_cashback(
                db_session, test_user.id, Decimal("1.00"), test_bar.id
            )
        
        assert exc_info.value.status_code == 400
        assert "insufficient_balance" in str(exc_info.value.detail)


class TestExpireCashback:
    """Test cashback expiration functionality."""
    
    def test_expire_available_cashback(self, db_session, test_user, test_bar, test_order):
        """Test expiring available cashback."""
        # Earn cashback with expiry
        request = EarnCashbackRequest(
            user_id=test_user.id,
            order_id=test_order.id,
            bar_id=test_bar.id,
            order_total=Decimal("100.00"),
            cashback_percentage=Decimal("0.05"),
            funded_by=FundingSource.BARZ,
            expires_days=1
        )
        transaction, _ = WalletService.earn_cashback(db_session, request, auto_available=True)
        
        # Expire it
        expired_transaction = WalletService.expire_cashback(db_session, transaction.id)
        
        assert expired_transaction.status == CashbackStatus.EXPIRED
        
        # Check balance removed
        wallet = WalletService.get_or_create_wallet(db_session, test_user.id)
        assert wallet.available_balance == Decimal("0.00")
    
    def test_expire_pending_cashback(self, db_session, test_user, test_bar, test_order):
        """Test expiring pending cashback."""
        # Earn pending cashback
        request = EarnCashbackRequest(
            user_id=test_user.id,
            order_id=test_order.id,
            bar_id=test_bar.id,
            order_total=Decimal("100.00"),
            cashback_percentage=Decimal("0.05"),
            funded_by=FundingSource.BARZ,
            expires_days=1
        )
        transaction, _ = WalletService.earn_cashback(db_session, request, auto_available=False)
        
        # Expire it
        expired_transaction = WalletService.expire_cashback(db_session, transaction.id)
        
        assert expired_transaction.status == CashbackStatus.EXPIRED
        
        # Check pending balance removed
        wallet = WalletService.get_or_create_wallet(db_session, test_user.id)
        assert wallet.pending_balance == Decimal("0.00")
    
    def test_process_expired_transactions(self, db_session, test_user, test_bar, test_order):
        """Test batch processing of expired transactions."""
        # Create multiple cashback transactions with past expiry dates
        past_date = datetime.now(timezone.utc) - timedelta(days=1)
        
        # Transaction 1: expired
        txn1 = CashbackLedger(
            user_id=test_user.id,
            order_id=test_order.id,
            bar_id=test_bar.id,
            amount=Decimal("5.00"),
            type=CashbackType.EARN,
            funded_by=FundingSource.BARZ,
            status=CashbackStatus.AVAILABLE,
            created_at=datetime.now(timezone.utc),
            expires_at=past_date
        )
        db_session.add(txn1)
        
        # Transaction 2: expired
        txn2 = CashbackLedger(
            user_id=test_user.id,
            order_id=test_order.id,
            bar_id=test_bar.id,
            amount=Decimal("3.00"),
            type=CashbackType.EARN,
            funded_by=FundingSource.BAR,
            status=CashbackStatus.AVAILABLE,
            created_at=datetime.now(timezone.utc),
            expires_at=past_date
        )
        db_session.add(txn2)
        
        # Update wallet
        wallet = WalletService.get_or_create_wallet(db_session, test_user.id)
        wallet.available_balance = Decimal("8.00")
        db_session.commit()
        
        # Process expirations
        count = WalletService.process_expirations(db_session)
        
        assert count == 2
        
        # Check wallet updated
        wallet = WalletService.get_or_create_wallet(db_session, test_user.id)
        assert wallet.available_balance == Decimal("0.00")
    
    def test_process_expirations_ignores_future_expiry(self, db_session, test_user, test_bar, test_order):
        """Test that future expiry dates are not processed."""
        # Create cashback with future expiry
        future_date = datetime.now(timezone.utc) + timedelta(days=30)
        
        txn = CashbackLedger(
            user_id=test_user.id,
            order_id=test_order.id,
            bar_id=test_bar.id,
            amount=Decimal("5.00"),
            type=CashbackType.EARN,
            funded_by=FundingSource.BARZ,
            status=CashbackStatus.AVAILABLE,
            created_at=datetime.now(timezone.utc),
            expires_at=future_date
        )
        db_session.add(txn)
        
        wallet = WalletService.get_or_create_wallet(db_session, test_user.id)
        wallet.available_balance = Decimal("5.00")
        db_session.commit()
        
        # Process expirations
        count = WalletService.process_expirations(db_session)
        
        assert count == 0  # Should not expire
        
        # Wallet should still have balance
        wallet = WalletService.get_or_create_wallet(db_session, test_user.id)
        assert wallet.available_balance == Decimal("5.00")


class TestTransactionHistory:
    """Test transaction history retrieval."""
    
    def test_get_empty_history(self, db_session, test_user):
        """Test getting history with no transactions."""
        transactions, count = WalletService.get_transaction_history(db_session, test_user.id)
        
        assert len(transactions) == 0
        assert count == 0
    
    def test_get_transaction_history_ordered(self, db_session, test_user, test_bar, test_order):
        """Test transaction history is ordered by created_at descending."""
        # Create multiple transactions with different times
        for i in range(3):
            request = EarnCashbackRequest(
                user_id=test_user.id,
                order_id=test_order.id,
                bar_id=test_bar.id,
                order_total=Decimal("100.00"),
                cashback_percentage=Decimal("0.05"),
                funded_by=FundingSource.BARZ
            )
            WalletService.earn_cashback(db_session, request, auto_available=True)
        
        transactions, count = WalletService.get_transaction_history(db_session, test_user.id)
        
        assert count == 3
        assert len(transactions) == 3
        # Check ordered by most recent first
        for i in range(len(transactions) - 1):
            assert transactions[i].created_at >= transactions[i + 1].created_at
    
    def test_get_history_with_pagination(self, db_session, test_user, test_bar, test_order):
        """Test transaction history pagination."""
        # Create 5 transactions
        for i in range(5):
            request = EarnCashbackRequest(
                user_id=test_user.id,
                order_id=test_order.id,
                bar_id=test_bar.id,
                order_total=Decimal("100.00"),
                cashback_percentage=Decimal("0.05"),
                funded_by=FundingSource.BARZ
            )
            WalletService.earn_cashback(db_session, request, auto_available=True)
        
        # Get page 1 with page_size=2
        page1_txns, count = WalletService.get_transaction_history(
            db_session, test_user.id, page=1, page_size=2
        )
        
        assert count == 5
        assert len(page1_txns) == 2
        
        # Get page 2
        page2_txns, _ = WalletService.get_transaction_history(
            db_session, test_user.id, page=2, page_size=2
        )
        
        assert len(page2_txns) == 2
        assert page1_txns[0].id != page2_txns[0].id  # Different transactions
    
    def test_filter_by_transaction_type(self, db_session, test_user, test_bar, test_order):
        """Test filtering transaction history by type."""
        # Earn cashback
        earn_req = EarnCashbackRequest(
            user_id=test_user.id,
            order_id=test_order.id,
            bar_id=test_bar.id,
            order_total=Decimal("100.00"),
            cashback_percentage=Decimal("0.05"),
            funded_by=FundingSource.BARZ
        )
        WalletService.earn_cashback(db_session, earn_req, auto_available=True)
        
        # Redeem cashback
        WalletService.redeem_cashback(db_session, test_user.id, Decimal("2.00"), test_bar.id)
        
        # Filter by EARN
        earn_txns, earn_count = WalletService.get_transaction_history(
            db_session, test_user.id, transaction_type=CashbackType.EARN
        )
        
        assert earn_count == 1
        assert all(txn.type == CashbackType.EARN for txn in earn_txns)
        
        # Filter by REDEEM
        redeem_txns, redeem_count = WalletService.get_transaction_history(
            db_session, test_user.id, transaction_type=CashbackType.REDEEM
        )
        
        assert redeem_count == 1
        assert all(txn.type == CashbackType.REDEEM for txn in redeem_txns)


class TestAdjustBalance:
    """Test manual balance adjustment (admin operation)."""
    
    def test_adjust_balance_positive(self, db_session, test_user, test_bar):
        """Test adding credit to wallet."""
        transaction, wallet = WalletService.adjust_balance(
            db_session, test_user.id, Decimal("20.00"), test_bar.id, "Compensation"
        )
        
        assert transaction.amount == Decimal("20.00")
        assert transaction.type == CashbackType.ADJUST
        assert transaction.status == CashbackStatus.AVAILABLE
        
        assert wallet.available_balance == Decimal("20.00")
    
    def test_adjust_balance_negative(self, db_session, test_user, test_bar, test_order):
        """Test deducting from wallet."""
        # First add some balance
        earn_req = EarnCashbackRequest(
            user_id=test_user.id,
            order_id=test_order.id,
            bar_id=test_bar.id,
            order_total=Decimal("200.00"),
            cashback_percentage=Decimal("0.05"),
            funded_by=FundingSource.BARZ
        )
        WalletService.earn_cashback(db_session, earn_req, auto_available=True)
        
        # Adjust negative
        transaction, wallet = WalletService.adjust_balance(
            db_session, test_user.id, Decimal("-5.00"), test_bar.id, "Correction"
        )
        
        assert transaction.amount == Decimal("-5.00")
        assert wallet.available_balance == Decimal("5.00")  # 10.00 - 5.00
