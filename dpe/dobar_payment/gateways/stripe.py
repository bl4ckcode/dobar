from typing import Dict, Any, Optional, Set
from functools import partial
import asyncio
import logging
import os

from stripe import StripeClient
from stripe._error import StripeError

from dobar_payment.interfaces import PaymentGateway, GatewayCapability
from dobar_payment.utils import normalize_currency, to_cents

logger = logging.getLogger(__name__)

ERR_NOT_CONFIGURED = "Stripe API key not configured"


class StripePaymentGateway(PaymentGateway):
    GATEWAY_NAME = "stripe"
    SUPPORTED_CURRENCIES: Set[str] = {"USD", "BRL", "EUR", "MXN", "ARS", "CLP", "COP", "PEN"}
    CAPABILITIES: Set[GatewayCapability] = {
        GatewayCapability.CREDIT_CARD,
        GatewayCapability.DEBIT_CARD,
        GatewayCapability.APPLE_PAY,
        GatewayCapability.GOOGLE_PAY,
        GatewayCapability.AUTH_ONLY,
        GatewayCapability.PARTIAL_CAPTURE,
        GatewayCapability.PARTIAL_REFUND,
        GatewayCapability.SAVED_CARDS,
        GatewayCapability.WEBHOOKS,
        GatewayCapability.THREE_D_SECURE,
    }

    def __init__(self, config: Dict[str, Any]):
        super().__init__(config)
        api_key = config.get("STRIPE_API_KEY") or os.getenv("STRIPE_API_KEY")
        self._configured = bool(api_key)
        self._client = StripeClient(api_key) if self._configured else None

    @property
    def is_configured(self) -> bool:
        return self._configured

    async def _run_sync(self, func, *args, **kwargs):
        return await asyncio.to_thread(partial(func, *args, **kwargs))

    def _error(self, message: str, **extra) -> Dict[str, Any]:
        return {"status": "error", "provider": self.GATEWAY_NAME, "message": message, **extra}

    def _normalize_intent(self, intent) -> Dict[str, Any]:
        status_map = {
            "succeeded": "success",
            "requires_action": "requires_action",
            "requires_payment_method": "error",
            "processing": "processing",
            "canceled": "canceled",
            "requires_capture": "requires_capture",
        }
        result = {
            "status": status_map.get(intent.status, intent.status),
            "provider": self.GATEWAY_NAME,
            "payment_intent_id": intent.id,
            "client_secret": intent.client_secret,
            "amount": intent.amount,
            "currency": intent.currency,
            "raw_status": intent.status,
        }
        if intent.status == "requires_action" and intent.next_action:
            if hasattr(intent.next_action, "redirect_to_url") and intent.next_action.redirect_to_url:
                result["redirect_url"] = intent.next_action.redirect_to_url.url
        if intent.latest_charge:
            result["charge_id"] = intent.latest_charge
        return result

    async def create_charge(
        self,
        amount: float,
        currency: str,
        customer: Optional[Dict[str, Any]] = None,
        payment_method: Optional[Dict[str, Any]] = None,
        idempotency_key: Optional[str] = None,
        **kwargs
    ) -> Dict[str, Any]:
        if not self._configured:
            return self._error(ERR_NOT_CONFIGURED)
        pm_data = payment_method or {}
        pm_id = pm_data.get("payment_method_id") or pm_data.get("payment_method")
        if not pm_id:
            return self._error("payment_method_id is required")
        cust = customer or {}
        params = {
            "amount": to_cents(amount),
            "currency": normalize_currency(currency, "stripe"),
            "payment_method": pm_id,
            "confirm": True,
            "return_url": kwargs.get("return_url", "https://dobar.app/payment/return"),
        }
        if cust.get("stripe_customer_id"):
            params["customer"] = cust["stripe_customer_id"]
        if cust.get("email"):
            params["receipt_email"] = cust["email"]
        if kwargs.get("metadata"):
            params["metadata"] = kwargs["metadata"]
        try:
            intent = await self._run_sync(self._client.v1.payment_intents.create, params)
            return self._normalize_intent(intent)
        except StripeError as e:
            return self._error(str(e.user_message) if hasattr(e, "user_message") else str(e), code=getattr(e, "code", None))
        except Exception as e:
            return self._error(f"Unexpected: {e}")

    async def refund_charge(
        self,
        charge_id: Optional[str] = None,
        payment_intent_id: Optional[str] = None,
        amount: Optional[float] = None,
        idempotency_key: Optional[str] = None,
        **kwargs
    ) -> Dict[str, Any]:
        if not self._configured:
            return self._error(ERR_NOT_CONFIGURED)
        if not charge_id and not payment_intent_id:
            return self._error("Either charge_id or payment_intent_id required")
        params = {}
        if charge_id:
            params["charge"] = charge_id
        else:
            params["payment_intent"] = payment_intent_id
        if amount is not None:
            params["amount"] = to_cents(amount)
        try:
            refund = await self._run_sync(self._client.v1.refunds.create, params)
            return {
                "status": "success",
                "provider": self.GATEWAY_NAME,
                "refund_id": refund.id,
                "amount_refunded": refund.amount,
                "currency": refund.currency,
            }
        except StripeError as e:
            return self._error(str(e.user_message) if hasattr(e, "user_message") else str(e))
        except Exception as e:
            return self._error(f"Unexpected: {e}")

    async def capture_charge(
        self,
        payment_intent_id: str,
        amount: Optional[float] = None,
        idempotency_key: Optional[str] = None,
        **kwargs
    ) -> Dict[str, Any]:
        if not self._configured:
            return self._error(ERR_NOT_CONFIGURED)
        params = {}
        if amount is not None:
            params["amount_to_capture"] = to_cents(amount)
        try:
            intent = await self._run_sync(
                self._client.v1.payment_intents.capture,
                payment_intent_id,
                params if params else None
            )
            return self._normalize_intent(intent)
        except StripeError as e:
            return self._error(str(e.user_message) if hasattr(e, "user_message") else str(e))
        except Exception as e:
            return self._error(f"Unexpected: {e}")

    async def create_checkout_session(
        self,
        success_url: str,
        cancel_url: str,
        amount: Optional[float] = None,
        currency: str = "usd",
        product_name: str = "Dobar Payment",
        **kwargs
    ) -> Dict[str, Any]:
        if not self._configured:
            return self._error(ERR_NOT_CONFIGURED)
        params = {
            "success_url": success_url,
            "cancel_url": cancel_url,
            "payment_method_types": kwargs.get("payment_method_types", ["card"]),
            "mode": "payment",
            "line_items": [{
                "price_data": {
                    "currency": normalize_currency(currency, "stripe"),
                    "product_data": {"name": product_name},
                    "unit_amount": to_cents(amount or 29.90),
                },
                "quantity": 1,
            }],
        }
        if kwargs.get("metadata"):
            params["metadata"] = kwargs["metadata"]
        if kwargs.get("customer_email"):
            params["customer_email"] = kwargs["customer_email"]
        try:
            session = await self._run_sync(self._client.v1.checkout.sessions.create, params)
            return {
                "status": "success",
                "provider": self.GATEWAY_NAME,
                "session_id": session.id,
                "checkout_url": session.url,
            }
        except StripeError as e:
            return self._error(str(e.user_message) if hasattr(e, "user_message") else str(e))
        except Exception as e:
            return self._error(f"Unexpected: {e}")

    async def create_setup_intent(self, customer_id: str, **kwargs) -> Dict[str, Any]:
        if not self._configured:
            return self._error(ERR_NOT_CONFIGURED)
        params = {
            "customer": customer_id,
            "payment_method_types": kwargs.get("payment_method_types", ["card"]),
        }
        if kwargs.get("metadata"):
            params["metadata"] = kwargs["metadata"]
        try:
            intent = await self._run_sync(self._client.v1.setup_intents.create, params)
            return {
                "status": "success",
                "provider": self.GATEWAY_NAME,
                "setup_intent_id": intent.id,
                "client_secret": intent.client_secret,
            }
        except StripeError as e:
            return self._error(str(e.user_message) if hasattr(e, "user_message") else str(e))
        except Exception as e:
            return self._error(f"Unexpected: {e}")

    async def create_customer(self, customer: Dict[str, Any], **kwargs) -> Dict[str, Any]:
        if not self._configured:
            return self._error(ERR_NOT_CONFIGURED)
        params = {"email": customer["email"]}
        if customer.get("name"):
            params["name"] = customer["name"]
        if kwargs.get("metadata"):
            params["metadata"] = kwargs["metadata"]
        try:
            cust = await self._run_sync(self._client.v1.customers.create, params)
            return {
                "status": "success",
                "provider": self.GATEWAY_NAME,
                "customer_id": cust.id,
                "email": cust.email,
            }
        except StripeError as e:
            return self._error(str(e.user_message) if hasattr(e, "user_message") else str(e))
        except Exception as e:
            return self._error(f"Unexpected: {e}")

    async def get_charge(self, charge_id: str, **kwargs) -> Dict[str, Any]:
        if not self._configured:
            return self._error(ERR_NOT_CONFIGURED)
        try:
            intent = await self._run_sync(self._client.v1.payment_intents.retrieve, charge_id)
            return self._normalize_intent(intent)
        except StripeError as e:
            return self._error(str(e.user_message) if hasattr(e, "user_message") else str(e))
        except Exception as e:
            return self._error(f"Unexpected: {e}")
