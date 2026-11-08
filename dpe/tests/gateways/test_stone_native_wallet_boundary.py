"""C10 boundary: PagarMe (Stone) must not claim or accept native wallet payloads
until the wallet-token mapping is verified against merchant sandbox access."""
import unittest
from unittest.mock import MagicMock, patch

from dobar_payment.gateways.stone import StonePaymentGateway
from dobar_payment.interfaces import GatewayCapability


class NativeWalletBoundary(unittest.IsolatedAsyncioTestCase):
    def gateway(self):
        with patch("dobar_payment.gateways.stone._get_pagarme_client", return_value=MagicMock()):
            return StonePaymentGateway({"PAGARME_USERNAME": "sk_test_x"})

    def test_capabilities_do_not_advertise_wallets(self):
        self.assertNotIn(GatewayCapability.APPLE_PAY, StonePaymentGateway.CAPABILITIES)
        self.assertNotIn(GatewayCapability.GOOGLE_PAY, StonePaymentGateway.CAPABILITIES)

    async def test_wallet_method_is_rejected_before_any_provider_call(self):
        gw = self.gateway()
        customer = {"name": "Teste", "email": "t@example.com", "document": "52998224725"}
        for method in ("apple_pay", "google_pay"):
            result = await gw.create_charge(
                amount=10.0, currency="BRL", customer=customer,
                payment_method={"type": method, "token": "opaque-wallet-payload"},
                amount_cents=1000,
            )
            self.assertEqual(result["status"], "error")
            self.assertEqual(result["error_code"], "INVALID_PAYMENT_METHOD")
        gw._client.orders.create_order.assert_not_called()


if __name__ == "__main__":
    unittest.main()
