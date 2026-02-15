import pytest
from decimal import Decimal
from unittest.mock import Mock, patch, AsyncMock

from app.payment.dpe_client import DPEClient


@pytest.mark.asyncio
class TestPaymentContractIntegrity:
    
    async def test_dpe_charge_contract(self):
        client = DPEClient(base_url="http://test.local", service_secret="test_secret")
        
        with patch.object(client, '_make_request', new_callable=AsyncMock) as mock_request:
            mock_request.return_value = {
                "status": "success",
                "payment_intent_id": "pi_test_123",
                "amount": 10000,
                "currency": "usd"
            }
            
            result = await client.charge(
                order_id=1,
                user_id=1,
                bar_id=1,
                amount=100.00,
                currency="usd",
                payment_method={"type": "card"},
                idempotency_key="test_key_123"
            )
            
            assert "status" in result, "Missing 'status' in charge response"
            assert "payment_intent_id" in result, "Missing 'payment_intent_id' in charge response"
            assert "amount" in result, "Missing 'amount' in charge response"
            assert "currency" in result, "Missing 'currency' in charge response"
            
            mock_request.assert_called_once()
            call_args = mock_request.call_args
            assert call_args[0][0] == "POST", "Charge should use POST method"
            assert "/charge" in call_args[0][1], "Charge endpoint contract broken"
    
    async def test_dpe_refund_contract(self):
        client = DPEClient(base_url="http://test.local", service_secret="test_secret")
        
        with patch.object(client, '_make_request', new_callable=AsyncMock) as mock_request:
            mock_request.return_value = {
                "status": "success",
                "refund_id": "re_test_123",
                "amount": 5000
            }
            
            result = await client.refund(
                payment_intent_id="pi_test_123",
                amount=50.00,
                reason="customer_request"
            )
            
            assert "status" in result, "Missing 'status' in refund response"
            assert "refund_id" in result, "Missing 'refund_id' in refund response"
            assert "amount" in result, "Missing 'amount' in refund response"
            
            mock_request.assert_called_once()
            call_args = mock_request.call_args
            assert call_args[0][0] == "POST", "Refund should use POST method"
            assert "/refund" in call_args[0][1], "Refund endpoint contract broken"
    
    async def test_dpe_create_pix_contract(self):
        client = DPEClient(base_url="http://test.local", service_secret="test_secret")
        
        with patch.object(client, '_make_request', new_callable=AsyncMock) as mock_request:
            mock_request.return_value = {
                "status": "success",
                "pix_code": "00020126580014br.gov.bcb.pix",
                "qr_code_url": "https://example.com/qr.png",
                "expires_at": "2026-02-15T00:00:00Z"
            }
            
            result = await client.create_pix(
                order_id=1,
                amount=100.00,
                user_id=1
            )
            
            assert "status" in result, "Missing 'status' in PIX response"
            assert "pix_code" in result or "qr_code" in result, "Missing PIX code in response"
            
            mock_request.assert_called_once()
    
    async def test_dpe_get_payment_status_contract(self):
        client = DPEClient(base_url="http://test.local", service_secret="test_secret")
        
        with patch.object(client, '_make_request', new_callable=AsyncMock) as mock_request:
            mock_request.return_value = {
                "status": "succeeded",
                "payment_intent_id": "pi_test_123",
                "amount": 10000,
                "currency": "usd"
            }
            
            result = await client.get_payment_status(payment_intent_id="pi_test_123")
            
            assert "status" in result, "Missing 'status' in payment status response"
            assert "payment_intent_id" in result, "Missing 'payment_intent_id' in response"
            
            mock_request.assert_called_once()
            call_args = mock_request.call_args
            assert call_args[0][0] == "GET", "Get payment status should use GET method"
    
    async def test_payment_gateway_integration_contract(self):
        from app.payment.payment_gateway import PaymentGateway
        
        gateway = PaymentGateway()
        
        assert hasattr(gateway, 'create_charge'), "Missing create_charge method"
        assert hasattr(gateway, 'refund_charge'), "Missing refund_charge method"
        assert hasattr(gateway, 'get_payment_status'), "Missing get_payment_status method"
        
        import inspect
        
        create_charge_sig = inspect.signature(gateway.create_charge)
        expected_params = ['amount', 'currency', 'payment_method', 'order_id', 'user_id', 'bar_id', 'idempotency_key']
        actual_params = list(create_charge_sig.parameters.keys())
        
        for param in expected_params:
            assert param in actual_params, f"Missing parameter '{param}' in create_charge"
