"""
Payment module for barz-backend.

STUB: dobar-payment-engine is WIP. This provides minimal interface for cart.py and routes.py to work.
TODO: Replace with actual dobar-payment-engine when ready.
"""

from typing import Any, Dict, Optional


class PaymentGateway:
    """Stub payment gateway - returns mock successful payments."""
    
    def create_charge(
        self,
        amount: int,
        currency: str,
        customer: Dict[str, Any],
        payment_method: Dict[str, Any]
    ) -> Dict[str, Any]:
        """Mock charge - always succeeds for now."""
        return {
            "id": f"stub_charge_{amount}",
            "status": "succeeded",
            "amount": amount,
            "currency": currency,
            "message": "Payment processed (stub mode)"
        }
    
    def refund_charge(self, **kwargs) -> Dict[str, Any]:
        """Mock refund - always succeeds."""
        return {
            "id": f"stub_refund_{kwargs.get('charge_id', 'unknown')}",
            "status": "succeeded",
            "message": "Refund processed (stub mode)"
        }
    
    def capture_charge(self, payment_intent_id: str, amount: Optional[float] = None) -> Dict[str, Any]:
        """Mock capture - always succeeds."""
        return {
            "id": payment_intent_id,
            "status": "succeeded",
            "message": "Capture processed (stub mode)"
        }
    
    def create_checkout_session(self, success_url: str, cancel_url: str) -> Dict[str, Any]:
        """Mock checkout session."""
        return {
            "id": "stub_checkout_session",
            "url": success_url,
            "status": "created",
            "message": "Checkout session created (stub mode)"
        }
    
    def create_setup_intent(self, customer_id: str) -> Dict[str, Any]:
        """Mock setup intent."""
        return {
            "id": f"stub_setup_{customer_id}",
            "client_secret": "stub_secret",
            "status": "requires_payment_method",
            "message": "Setup intent created (stub mode)"
        }


def get_payment_gateway() -> PaymentGateway:
    """FastAPI dependency that returns a PaymentGateway instance."""
    return PaymentGateway()


__all__ = ["PaymentGateway", "get_payment_gateway"]
