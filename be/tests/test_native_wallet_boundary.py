"""C10 boundary: until PagarMe wallet-token mapping is verified, Brazilian
purchases accept only provider card tokens/saved cards and never advertise
Apple Pay / Google Pay."""
import pytest

from app.auth.profile import get_payment_methods_for_country, get_gateway_for_country
from app.errors import APIError
from app.payment.order_payments import resolve_payment_method

pytestmark = pytest.mark.asyncio


def test_brazil_routes_to_pagarme_without_native_wallets():
    assert get_gateway_for_country("BR") == "stone"
    methods = get_payment_methods_for_country("BR")
    assert "apple_pay" not in methods and "google_pay" not in methods
    assert "pix" in methods  # Pix stays a checkout method; it is never a saved method


@pytest.mark.parametrize("provider", ["apple_pay", "google_pay"])
async def test_wallet_payload_is_not_accepted_as_a_card_token(provider):
    # A native wallet blob is not a PagarMe tokenizecard token ("token_...").
    with pytest.raises(APIError) as err:
        await resolve_payment_method(None, 1, {"type": "card", "token": "eyJwYXlsb2FkIjoid2FsbGV0In0=", "provider": provider})
    assert err.value.status_code == 422


@pytest.mark.parametrize("method", ["apple_pay", "google_pay"])
async def test_wallet_is_not_a_payment_type(method):
    with pytest.raises(APIError):
        await resolve_payment_method(None, 1, {"type": method, "token": "token_abc"})
