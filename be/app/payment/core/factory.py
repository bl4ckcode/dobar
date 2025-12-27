from app.payment.core.gateways._stripe_payment_gateway import StripePaymentGateway
from app.payment.core.gateways._paypal_payment_gateway import PaypalPaymentGateway
from .interfaces import PaymentGateway
from .gateways._stone_payment_gateway import StonePaymentGateway
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
        return StripePaymentGateway(config={"STRIPE_API_KEY": os.getenv("STRIPE_API_KEY")})
    elif gateway_name == 'paypal':
        return PaypalPaymentGateway(
            config={
                "PAYPAL_CLIENT_ID": os.getenv("PAYPAL_CLIENT_ID"),
                "PAYPAL_CLIENT_SECRET": os.getenv("PAYPAL_CLIENT_SECRET"),
                "PAYPAL_ENV": os.getenv("PAYPAL_ENV", "sandbox"),
            }
        )
    else:
        raise ValueError(f"Unknown payment gateway: {gateway_name}")

