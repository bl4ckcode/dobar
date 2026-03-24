import unittest
from unittest.mock import MagicMock, patch
import asyncio
from dobar_payment.gateways.stone import StonePaymentGateway

class TestStoneGateway(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.config = {
            "PAGARME_USERNAME": "test_user",
            "PAGARME_PASSWORD": "test_password"
        }
        with patch('dobar_payment.gateways.stone._get_pagarme_client') as mock_client:
            self.gateway = StonePaymentGateway(self.config)
            self.gateway._client = MagicMock()

    async def test_normalize_pix_order(self):
        mock_response = MagicMock()
        mock_response.id = "ord_123"
        mock_response.status = "pending"
        mock_response.amount = 1000
        
        mock_charge = MagicMock()
        mock_charge.id = "ch_123"
        mock_charge.status = "pending"
        
        mock_tx = MagicMock()
        mock_tx.id = "tx_123"
        mock_tx.status = "waiting_payment"
        mock_tx.qr_code = "00020126330014BR.GOV.BCB.PIX..."
        mock_tx.qr_code_url = "https://api.pagar.me/pix/qr/123.png"
        
        mock_charge.last_transaction = mock_tx
        mock_response.charges = [mock_charge]
        
        result = self.gateway._normalize_order(mock_response, "pix")
        self.assertEqual(result["status"], "success")
        self.assertEqual(result["pix_qr_code"], mock_tx.qr_code)
        self.assertEqual(result["pix_copia_e_cola"], mock_tx.qr_code)
        self.assertEqual(result["pix_qr_code_url"], mock_tx.qr_code_url)

    async def test_normalize_cc_order(self):
        mock_response = MagicMock()
        mock_response.id = "ord_456"
        mock_response.status = "paid"
        
        mock_charge = MagicMock()
        mock_charge.id = "ch_456"
        mock_charge.status = "paid"
        
        mock_tx = MagicMock()
        mock_tx.id = "tx_456"
        mock_tx.status = "captured"
        mock_tx.acquirer_message = "Success"
        mock_tx.brand = "visa"
        mock_tx.last_four_digits = "1234"
        
        mock_charge.last_transaction = mock_tx
        mock_response.charges = [mock_charge]
        
        result = self.gateway._normalize_order(mock_response, "credit_card")
        self.assertEqual(result["status"], "success")
        self.assertEqual(result["transaction_status"], "captured")
        self.assertEqual(result["card_brand"], "visa")
        self.assertEqual(result["card_last_four"], "1234")

    async def test_refund_charge(self):
        mock_response = MagicMock()
        mock_response.id = "re_789"
        mock_response.status = "canceled"
        mock_response.canceled_amount = 5000
        
        with patch.object(self.gateway, '_run_sync', return_value=mock_response):
            result = await self.gateway.refund_charge(charge_id="ch_789", amount=50.0)
        
        self.assertEqual(result["status"], "success")
        self.assertEqual(result["refund_id"], "re_789")
        self.assertEqual(result["charge_status"], "canceled")

if __name__ == '__main__':
    unittest.main()
