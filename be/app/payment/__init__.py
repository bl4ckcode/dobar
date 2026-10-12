import os
from typing import Any, Dict, Optional

USE_DPE = os.getenv("USE_DPE", "false").lower() == "true"


class PaymentGateway:
    
    def create_charge(
        self,
        amount: int,
        currency: str,
        customer: Dict[str, Any],
        payment_method: Dict[str, Any]
    ) -> Dict[str, Any]:
        return {
            "id": f"stub_charge_{amount}",
            "status": "succeeded",
            "amount": amount,
            "currency": currency,
            "message": "Payment processed (stub mode)"
        }
    
    def refund_charge(self, **kwargs) -> Dict[str, Any]:
        return {
            "id": f"stub_refund_{kwargs.get('charge_id', 'unknown')}",
            "status": "succeeded",
            "message": "Refund processed (stub mode)"
        }
    
    def capture_charge(self, payment_intent_id: str, amount: Optional[float] = None) -> Dict[str, Any]:
        return {
            "id": payment_intent_id,
            "status": "succeeded",
            "message": "Capture processed (stub mode)"
        }
    
    def create_checkout_session(self, success_url: str, cancel_url: str) -> Dict[str, Any]:
        return {
            "id": "stub_checkout_session",
            "url": success_url,
            "status": "created",
            "message": "Checkout session created (stub mode)"
        }
    
    def create_setup_intent(self, customer_id: str) -> Dict[str, Any]:
        return {
            "id": f"stub_setup_{customer_id}",
            "client_secret": "stub_secret",
            "status": "requires_payment_method",
            "message": "Setup intent created (stub mode)"
        }


def get_payment_gateway() -> PaymentGateway:
    return PaymentGateway()


from .dpe_client import DPEClient, get_dpe_client, close_dpe_client

__all__ = [
    "PaymentGateway", 
    "get_payment_gateway",
    "DPEClient",
    "get_dpe_client",
    "close_dpe_client",
    "USE_DPE",
]

