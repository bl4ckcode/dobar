"""Tests for dobar_payment interfaces."""
import pytest
from dobar_payment.interfaces import PaymentGateway, GatewayCapability


class TestGatewayCapability:
    """Test GatewayCapability enum."""
    
    def test_credit_card_capability(self):
        assert GatewayCapability.CREDIT_CARD.value == "credit_card"
    
    def test_pix_capability(self):
        assert GatewayCapability.PIX.value == "pix"
    
    def test_three_d_secure_capability(self):
        assert GatewayCapability.THREE_D_SECURE.value == "3ds"
    
    def test_all_capabilities_are_strings(self):
        for cap in GatewayCapability:
            assert isinstance(cap.value, str)


class TestPaymentGatewayInterface:
    """Test PaymentGateway abstract base class."""
    
    def test_cannot_instantiate_abstract_class(self):
        with pytest.raises(TypeError):
            PaymentGateway()
    
    def test_gateway_has_required_attributes(self):
        assert hasattr(PaymentGateway, 'GATEWAY_NAME')
        assert hasattr(PaymentGateway, 'create_charge')
        assert hasattr(PaymentGateway, 'refund_charge')
        assert hasattr(PaymentGateway, 'capture_charge')
