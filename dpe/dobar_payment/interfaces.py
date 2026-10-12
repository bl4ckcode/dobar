from abc import ABC, abstractmethod
from typing import Dict, Any, Optional, Set
from enum import Enum
import logging

logger = logging.getLogger("dobar.payment.gateway")


class GatewayCapability(str, Enum):
    CREDIT_CARD = "credit_card"
    DEBIT_CARD = "debit_card"
    PIX = "pix"
    BOLETO = "boleto"
    PAYPAL = "paypal"
    APPLE_PAY = "apple_pay"
    GOOGLE_PAY = "google_pay"
    AUTH_ONLY = "auth_only"
    PARTIAL_CAPTURE = "partial_capture"
    PARTIAL_REFUND = "partial_refund"
    INSTALLMENTS = "installments"
    SAVED_CARDS = "saved_cards"
    WEBHOOKS = "webhooks"
    THREE_D_SECURE = "3ds"
    RECURRING = "recurring"


class PaymentGateway(ABC):
    GATEWAY_NAME: str = "unknown"
    SUPPORTED_CURRENCIES: Set[str] = {"USD", "BRL", "EUR"}
    CAPABILITIES: Set[GatewayCapability] = set()

    def __init__(self, config: Dict[str, Any]):
        self._config = config
        self._healthy = True
        self._settlement_delay_days = config.get("SETTLEMENT_DELAY_DAYS", 7)

    @property
    def settlement_delay_days(self) -> int:
        return self._settlement_delay_days

    @abstractmethod
    async def create_charge(
        self,
        amount: float,
        currency: str,
        customer: Optional[Dict[str, Any]] = None,
        payment_method: Optional[Dict[str, Any]] = None,
        idempotency_key: Optional[str] = None,
        **kwargs
    ) -> Dict[str, Any]:
        pass

    @abstractmethod
    async def refund_charge(
        self,
        charge_id: Optional[str] = None,
        payment_intent_id: Optional[str] = None,
        amount: Optional[float] = None,
        idempotency_key: Optional[str] = None,
        **kwargs
    ) -> Dict[str, Any]:
        pass

    async def capture_charge(
        self,
        payment_intent_id: str,
        amount: Optional[float] = None,
        idempotency_key: Optional[str] = None,
        **kwargs
    ) -> Dict[str, Any]:
        return {
            "status": "error",
            "provider": self.GATEWAY_NAME,
            "message": f"Capture not supported by {self.GATEWAY_NAME}",
        }

    async def get_charge(self, charge_id: str, **kwargs) -> Dict[str, Any]:
        return {
            "status": "error",
            "provider": self.GATEWAY_NAME,
            "message": f"Get charge not implemented for {self.GATEWAY_NAME}",
        }

    async def create_customer(self, customer: Dict[str, Any], **kwargs) -> Dict[str, Any]:
        return {
            "status": "error",
            "provider": self.GATEWAY_NAME,
            "message": f"Create customer not implemented for {self.GATEWAY_NAME}",
        }

    async def create_setup_intent(self, customer_id: str, **kwargs) -> Dict[str, Any]:
        return {
            "status": "error",
            "provider": self.GATEWAY_NAME,
            "message": f"Setup intent not supported by {self.GATEWAY_NAME}",
        }

    async def create_checkout_session(
        self,
        success_url: str,
        cancel_url: str,
        **kwargs
    ) -> Dict[str, Any]:
        return {
            "status": "error",
            "provider": self.GATEWAY_NAME,
            "message": f"Checkout sessions not supported by {self.GATEWAY_NAME}",
        }

    async def health_check(self) -> Dict[str, Any]:
        return {"healthy": self._healthy, "gateway": self.GATEWAY_NAME}

    def supports(self, capability: GatewayCapability) -> bool:
        return capability in self.CAPABILITIES

    def supports_currency(self, currency: str) -> bool:
        return currency.upper() in self.SUPPORTED_CURRENCIES

    @property
    def is_configured(self) -> bool:
        return True
