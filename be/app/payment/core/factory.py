from app.payment.core.stripe.stripe import StripePaymentGateway
from .interfaces import PaymentGateway
from .pagarme._stone_payment_gateway import StonePaymentGateway
from dotenv import load_dotenv
import os

__all__ = ['get_payment_gateway']

load_dotenv()

def get_payment_gateway() -> PaymentGateway:
    gateway_name = os.getenv('PAYMENT_GATEWAY', 'stone')
    print(f"[DEBUG] Using payment gateway: {gateway_name}")  # 💥 log this

    if gateway_name == 'stone':
        return StonePaymentGateway(config={})
    elif gateway_name == 'stripe':
        return StripePaymentGateway(config={})
    else:
        raise ValueError(f"Unknown payment gateway: {gateway_name}")

