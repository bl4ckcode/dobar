from ..interfaces import PaymentGateway
from typing import Dict, Any
import app.payment.core.stripe.stripe as stripe

class StripePaymentGateway(PaymentGateway):
    def __init__(self, config: Dict[str, Any]):
        stripe.api_key = config.get("STRIPE_API_KEY")
        # Configure any additional settings if necessary

    def create_charge(self, amount: float, currency: str, **kwargs) -> Dict[str, Any]:
        # Use stripe.Charge.create() or stripe.PaymentIntent.create()
        charge = stripe.PaymentIntent.create(
            amount=int(amount * 100),  # Stripe expects amounts in cents
            currency=currency,
            **kwargs
        )
        return {"status": "success", "charge_id": charge.id}

    def refund_charge(self, charge_id: str, amount: float = None) -> Dict[str, Any]:
        refund = stripe.Refund.create(
            payment_intent=charge_id,
            amount=int(amount * 100) if amount else None
        )
        return {"status": "success", "refund_id": refund.id}