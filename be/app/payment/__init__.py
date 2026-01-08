"""
Payment module for barz-backend.

STUB: dobar-payment-engine is WIP. This provides minimal interface for cart.py to work.
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


def get_payment_gateway() -> PaymentGateway:
    """FastAPI dependency that returns a PaymentGateway instance."""
    return PaymentGateway()


__all__ = ["PaymentGateway", "get_payment_gateway"]
