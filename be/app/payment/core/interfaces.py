from abc import ABC, abstractmethod
from typing import Dict, Any, Optional


class PaymentGateway(ABC):
    @abstractmethod
    def create_charge(self, amount: float, currency: str, **kwargs) -> Dict[str, Any]:
        """Charge a given amount to a customer."""
        pass

    @abstractmethod
    def refund_charge(
        self,
        charge_id: Optional[str] = None,
        payment_intent_id: Optional[str] = None,
        amount: Optional[float] = None,
    ) -> Dict[str, Any]:
        """Refund a specific charge, either fully or partially."""
        pass

    def capture_charge(
        self,
        payment_intent_id: str,
        amount: Optional[float] = None,
    ) -> Dict[str, Any]:
        """Capture/confirm a previously-created payment intent/order.

        Default implementation indicates that the gateway does not support
        out-of-band capture confirmation. Concrete gateways that need a
        two-step flow (like PayPal Orders) should override this method.
        """
        return {
            "status": "error",
            "message": "Capture not supported for this gateway",
        }

    # Add other abstract/optional methods as needed (e.g., for subscriptions, customer creation, etc.)