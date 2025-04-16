from ..interfaces import PaymentGateway
from typing import Dict, Any, Optional
from app.payment.utils.currency import normalize_currency
import stripe

class StripePaymentGateway(PaymentGateway):
    def __init__(self, config: Dict[str, Any]):
        stripe.api_key = config.get("STRIPE_API_KEY")

    def create_charge(self, amount: float, currency: str, **kwargs) -> Dict[str, Any]:
        try:
            payment_method_data = kwargs.get("payment_method", {})
            customer_data = kwargs.get("customer", {})

            payment_method_id = payment_method_data.get("payment_method_id") or payment_method_data.get("payment_method")
            customer_id = customer_data.get("stripe_customer_id")  # Optional, for saved cards

            if not payment_method_id:
                return {"status": "error", "message": "Missing payment_method_id or test payment method"}

            # Confirming explicitly — no automatic_payment_methods
            intent = stripe.PaymentIntent.create(
                amount=int(amount * 100),
                currency=normalize_currency(currency, target="stripe"),
                payment_method=payment_method_id,
                customer=customer_id,
                confirm=True,
                receipt_email=customer_data.get("email"),
                return_url="https://barz.com.br/pay/return"  # Optional for wallets/redirects
            )

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
        
    def create_checkout_session(self, success_url: str, cancel_url: str) -> Dict[str, Any]:
        try:
            session = stripe.checkout.Session.create(
                success_url=success_url,
                cancel_url=cancel_url,
                payment_method_types=["card"],
                mode="payment",
                line_items=[{
                    "price_data": {
                        "currency": "brl",
                        "product_data": {
                            "name": "BarZ Ads Boost"
                        },
                        "unit_amount": 2990  # R$29.90
                    },
                    "quantity": 1
                }]
            )
            return {"status": "success", "checkout_url": session.url}
        except Exception as e:
            return {"status": "error", "message": str(e)}

