from abc import ABC, abstractmethod
from typing import Dict, Any

class PaymentGateway(ABC):
    @abstractmethod
    def create_charge(self, amount: float, currency: str, **kwargs) -> Dict[str, Any]:
        """Charge a given amount to a customer."""
        pass

    @abstractmethod
    def refund_charge(self, charge_id: str, amount: float = None) -> Dict[str, Any]:
        """Refund a specific charge, either fully or partially."""
        pass

    # Add other abstract methods as needed (e.g., for subscriptions, customer creation, etc.)