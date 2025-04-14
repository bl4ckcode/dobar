from ..interfaces import PaymentGateway
from typing import Dict, Any, Optional
from app.payment.utils.currency import normalize_currency
import stripe

class StripePaymentGateway(PaymentGateway):
    def __init__(self, config: Dict[str, Any]):
        stripe.api_key = config.get("STRIPE_API_KEY")

    def create_charge(self, amount: float, currency: str, **kwargs) -> Dict[str, Any]:
        try:
            if "payment_method_id" in kwargs:
                # PRODUCTION FLOW
                intent = stripe.PaymentIntent.create(
                    amount=int(amount * 100),
                    currency = normalize_currency(currency, target="stripe"),
                    payment_method=kwargs["payment_method_id"],
                    confirmation_method="manual",
                    confirm=True,
                    receipt_email=kwargs.get("customer_email")
                )
            elif "card" in kwargs:
                # DEV FLOW (raw card to token to payment_method)
                token = stripe.Token.create(card=kwargs["card"])
                payment_method = stripe.PaymentMethod.create(type="card", card={"token": token.id})
                intent = stripe.PaymentIntent.create(
                    amount=int(amount * 100),
                    currency=normalize_currency(currency, target="stripe"),
                    payment_method=payment_method.id,
                    confirmation_method="manual",
                    confirm=True,
                    receipt_email=kwargs.get("customer_email")
                )
            else:
                return {"status": "error", "message": "Missing payment_method_id or card"}

            return {
                "status": "success",
                "payment_intent_id": intent.id,
                "client_secret": intent.client_secret,
                "receipt_email": intent.receipt_email
            }

        except Exception as e:
            return {"status": "error", "message": str(e)}


    def refund_charge(self, charge_id: Optional[str] = None, payment_intent_id: Optional[str] = None, amount: Optional[float] = None) -> Dict[str, Any]:
        try:
            refund_params = {}

            if charge_id:
                refund_params["charge"] = charge_id
            elif payment_intent_id:
                refund_params["payment_intent"] = payment_intent_id
            else:
                return {"status": "error", "message": "Either charge_id or payment_intent_id is required"}

            if amount:
                refund_params["amount"] = int(amount * 100)

            refund = stripe.Refund.create(**refund_params)

            return {
                "status": "success",
                "refund_id": refund.id,
                "amount_refunded": refund.amount,
                "currency": normalize_currency(refund.currency, target="stripe"),
                "status_stripe": refund.status
            }

        except Exception as e:
            return {"status": "error", "message": str(e)}
