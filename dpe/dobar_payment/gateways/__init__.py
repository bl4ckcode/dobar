"""
dobar-payment-engine: Gateway Implementations

Available gateways:
- StripePaymentGateway: For global and LATAM (non-Brazil)
- StonePaymentGateway: For Brazil (Pagar.me)
- PaypalPaymentGateway: For global PayPal payments
"""

from .stripe import StripePaymentGateway
from .stone import StonePaymentGateway
from .paypal import PaypalPaymentGateway

__all__ = [
    "StripePaymentGateway",
    "StonePaymentGateway",
    "PaypalPaymentGateway",
]
