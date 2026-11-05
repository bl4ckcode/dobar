import logging
import uuid
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, Optional

logger = logging.getLogger("dobar.payment.api")


class InMemoryPaymentStore:
    def __init__(self):
        self._payments: Dict[str, Dict[str, Any]] = {}
        self._idempotency: Dict[str, Dict[str, Any]] = {}
        self._refunds: Dict[str, Dict[str, Any]] = {}
        self._pix: Dict[str, Dict[str, Any]] = {}

    def store_payment(self, payment_id: str, data: Dict[str, Any]) -> None:
        self._payments[payment_id] = {
            **data,
            "stored_at": datetime.now(timezone.utc).isoformat(),
        }

    def get_payment(self, payment_id: str) -> Optional[Dict[str, Any]]:
        return self._payments.get(payment_id)

    def update_payment(self, payment_id: str, updates: Dict[str, Any]) -> bool:
        if payment_id not in self._payments:
            return False
        self._payments[payment_id].update(updates)
        return True

    def find_gateway_payment(self, gateway: str, references: set[str]) -> Optional[Dict[str, Any]]:
        for payment in self._payments.values():
            if payment.get("gateway") == gateway and references.intersection(
                {
                    payment.get("gateway_id"),
                    payment.get("gateway_order_id"),
                    payment.get("gateway_transaction_id"),
                }
            ):
                return payment
        return None

    def check_idempotency(self, key: str) -> Optional[Dict[str, Any]]:
        cached = self._idempotency.get(key)
        if cached:
            expires_at = datetime.fromisoformat(cached["expires_at"])
            if datetime.now(timezone.utc) < expires_at:
                return cached["response"]
        return None

    def store_idempotency(
        self,
        key: str,
        response: Dict[str, Any],
        ttl_hours: int = 24,
        request_fingerprint: Optional[str] = None,
    ) -> None:
        self._idempotency[key] = {
            "response": response,
            "request_fingerprint": request_fingerprint,
            "expires_at": (datetime.now(timezone.utc) + timedelta(hours=ttl_hours)).isoformat(),
        }

    def idempotency_conflicts(self, key: str, request_fingerprint: str) -> bool:
        if self.check_idempotency(key) is None:
            return False
        previous = self._idempotency[key].get("request_fingerprint")
        return previous is not None and previous != request_fingerprint

    def store_refund(self, refund_id: str, data: Dict[str, Any]) -> None:
        self._refunds[refund_id] = {
            **data,
            "stored_at": datetime.now(timezone.utc).isoformat(),
        }

    def get_refund(self, refund_id: str) -> Optional[Dict[str, Any]]:
        return self._refunds.get(refund_id)

    def store_pix(self, pix_id: str, data: Dict[str, Any]) -> None:
        self._pix[pix_id] = {
            **data,
            "stored_at": datetime.now(timezone.utc).isoformat(),
        }

    def get_pix(self, pix_id: str) -> Optional[Dict[str, Any]]:
        return self._pix.get(pix_id)

    def update_pix(self, pix_id: str, updates: Dict[str, Any]) -> bool:
        if pix_id not in self._pix:
            return False
        self._pix[pix_id].update(updates)
        return True


class GatewayRegistry:
    def __init__(self):
        self._gateways: Dict[str, Any] = {}
        self._health: Dict[str, bool] = {}

    def register(self, name: str, gateway: Any) -> None:
        self._gateways[name] = gateway
        self._health[name] = True

    def get(self, name: str) -> Optional[Any]:
        return self._gateways.get(name)

    def get_for_country(self, country: str) -> Optional[tuple[str, Any]]:
        country_mapping = {
            "BR": "stone",
            "AR": "stripe",
            "CL": "stripe",
            "CO": "stripe",
            "PE": "stripe",
            "MX": "stripe",
            "US": "paypal",
            "CA": "paypal",
        }
        gateway_name = country_mapping.get(country.upper())
        if gateway_name and gateway_name in self._gateways:
            return gateway_name, self._gateways[gateway_name]
        if "paypal" in self._gateways:
            return "paypal", self._gateways["paypal"]
        return None

    def set_health(self, name: str, healthy: bool) -> None:
        self._health[name] = healthy

    def get_health_status(self) -> Dict[str, bool]:
        return self._health.copy()

    def list_gateways(self) -> list[str]:
        return list(self._gateways.keys())


payment_store = InMemoryPaymentStore()
gateway_registry = GatewayRegistry()


def generate_payment_id() -> str:
    return f"pay_{uuid.uuid4().hex[:16]}"


def generate_refund_id() -> str:
    return f"ref_{uuid.uuid4().hex[:16]}"


def generate_pix_id() -> str:
    return f"pix_{uuid.uuid4().hex[:16]}"
