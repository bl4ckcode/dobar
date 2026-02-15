import pytest
from decimal import Decimal
from datetime import datetime, timezone

from app.bars_and_restaurants.models.wallet_models import (
    CashbackLedger, UserWallet, BarWallet, CashbackType, CashbackStatus, FundingSource
)
from app.bars_and_restaurants.services.wallet_service import WalletService


@pytest.mark.asyncio
class TestWalletContractIntegrity:
    
    async def test_user_wallet_balance_calculation_contract(self, db_session, test_user):
        wallet = WalletService.get_or_create_wallet(db_session, test_user.id)
        wallet.available_balance = Decimal("50.00")
        wallet.pending_balance = Decimal("10.00")
        db_session.commit()
        
        response = WalletService.get_wallet_balance(db_session, test_user.id)
        
        assert hasattr(response, 'user_id'), "Missing user_id in wallet balance response"
        assert hasattr(response, 'available_balance'), "Missing available_balance"
        assert hasattr(response, 'pending_balance'), "Missing pending_balance"
        assert hasattr(response, 'total_balance'), "Missing total_balance"
        
        assert response.total_balance == Decimal("60.00"), "Total balance calculation broken"
    
    async def test_bar_wallet_reserve_release_contract(self, db_session, test_bar):
        wallet = WalletService.get_or_create_bar_wallet(db_session, test_bar.id)
        wallet.available_balance = Decimal("100.00")
        db_session.commit()
        
        initial_available = wallet.available_balance
        reserve_amount = Decimal("30.00")
        
        success = WalletService.reserve_bar_funds(db_session, test_bar.id, reserve_amount)
        assert success is True, "Reserve funds contract broken"
        
        wallet = WalletService.get_or_create_bar_wallet(db_session, test_bar.id)
        assert wallet.available_balance == initial_available - reserve_amount, "Available balance not updated"
        assert wallet.reserved_balance == reserve_amount, "Reserved balance not updated"
        
        WalletService.release_bar_funds(db_session, test_bar.id, reserve_amount)
        wallet = WalletService.get_or_create_bar_wallet(db_session, test_bar.id)
        assert wallet.available_balance == initial_available, "Release funds contract broken"
        assert wallet.reserved_balance == Decimal("0.00"), "Reserved balance not cleared"
    
    async def test_cashback_ledger_foreign_key_contract(self, db_session, test_user, test_bar, test_order):
        from app.bars_and_restaurants.schemas.wallet import EarnCashbackRequest
        
        request = EarnCashbackRequest(
            user_id=test_user.id,
            order_id=test_order.id,
            bar_id=test_bar.id,
            order_total=Decimal("100.00"),
            cashback_percentage=Decimal("0.05"),
            funded_by=FundingSource.BARZ
        )
        
        transaction, wallet = WalletService.earn_cashback(db_session, request, auto_available=True)
        
        assert isinstance(transaction.user_id, int), "user_id should be INTEGER"
        assert isinstance(transaction.bar_id, int), "bar_id should be INTEGER"
        assert isinstance(transaction.order_id, int), "order_id should be INTEGER"
        assert transaction.user_id == test_user.id, "Foreign key contract broken"
        assert transaction.bar_id == test_bar.id, "Foreign key contract broken"
    
    async def test_wallet_enum_values_contract(self, db_session, test_user, test_bar, test_order):
        from app.bars_and_restaurants.schemas.wallet import EarnCashbackRequest
        
        request = EarnCashbackRequest(
            user_id=test_user.id,
            order_id=test_order.id,
            bar_id=test_bar.id,
            order_total=Decimal("50.00"),
            cashback_percentage=Decimal("0.10"),
            funded_by=FundingSource.BAR
        )
        
        transaction, _ = WalletService.earn_cashback(db_session, request, auto_available=True)
        
        assert transaction.type == CashbackType.EARN, "CashbackType enum contract broken"
        assert transaction.status == CashbackStatus.AVAILABLE, "CashbackStatus enum contract broken"
        assert transaction.funded_by == FundingSource.BAR, "FundingSource enum contract broken"
    
    async def test_promotion_funding_validation_contract(self, db_session, test_bar):
        wallet = WalletService.get_or_create_bar_wallet(db_session, test_bar.id)
        wallet.available_balance = Decimal("50.00")
        db_session.commit()
        
        is_valid_barz = WalletService.validate_promotion_funding(
            db_session, test_bar.id, Decimal("1000.00"), FundingSource.BARZ
        )
        assert is_valid_barz is True, "BARZ funding validation contract broken"
        
        is_valid_bar_sufficient = WalletService.validate_promotion_funding(
            db_session, test_bar.id, Decimal("30.00"), FundingSource.BAR
        )
        assert is_valid_bar_sufficient is True, "Bar funding validation contract broken"
        
        is_valid_bar_insufficient = WalletService.validate_promotion_funding(
            db_session, test_bar.id, Decimal("100.00"), FundingSource.BAR
        )
        assert is_valid_bar_insufficient is False, "Bar funding validation contract broken"
