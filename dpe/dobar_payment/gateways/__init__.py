"""
dobar-payment-engine: Gateway Implementations

Available gateways:
- StripePaymentGateway: For global and LATAM (non-Brazil)
- StonePaymentGateway: For Brazil (Pagar.me)
- PaypalPaymentGateway: For global PayPal payments
"""

# Initialize pagarme_sdk path fix BEFORE importing Stone gateway
import dobar_payment.pagarme_sdk  # noqa: F401

from .stripe import StripePaymentGateway
from .stone import StonePaymentGateway
from .paypal import PaypalPaymentGateway

__all__ = [
    "StripePaymentGateway",
    "StonePaymentGateway",
    "PaypalPaymentGateway",
]
