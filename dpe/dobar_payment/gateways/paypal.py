from typing import Dict, Any, Optional, Set
from functools import partial
import asyncio
import os

from paypalserversdk.paypal_serversdk_client import PaypalServersdkClient
from paypalserversdk.configuration import Environment
from paypalserversdk.http.auth.o_auth_2 import ClientCredentialsAuthCredentials
from paypalserversdk.models.order_request import OrderRequest
from paypalserversdk.models.purchase_unit_request import PurchaseUnitRequest
from paypalserversdk.models.amount_with_breakdown import AmountWithBreakdown
from paypalserversdk.models.checkout_payment_intent import CheckoutPaymentIntent

from dobar_payment.interfaces import PaymentGateway, GatewayCapability
from dobar_payment.utils import normalize_currency

ERR_NOT_CONFIGURED = "PayPal credentials not configured"
PREFER_REPRESENTATION = "return=representation"


class PaypalPaymentGateway(PaymentGateway):
    GATEWAY_NAME = "paypal"
    SUPPORTED_CURRENCIES: Set[str] = {"USD", "BRL", "EUR", "MXN", "ARS"}
    CAPABILITIES: Set[GatewayCapability] = {
        GatewayCapability.PAYPAL,
        GatewayCapability.WEBHOOKS,
        GatewayCapability.PARTIAL_REFUND,
    }

    def __init__(self, config: Dict[str, Any]):
        super().__init__(config)
        client_id = config.get("PAYPAL_CLIENT_ID") or os.getenv("PAYPAL_CLIENT_ID")
        client_secret = config.get("PAYPAL_CLIENT_SECRET") or os.getenv("PAYPAL_CLIENT_SECRET")
        env_str = config.get("PAYPAL_ENV", "sandbox")
        self._configured = bool(client_id and client_secret)
        if self._configured:
            env = Environment.PRODUCTION if env_str == "live" else Environment.SANDBOX
            self._client = PaypalServersdkClient(
                client_credentials_auth_credentials=ClientCredentialsAuthCredentials(
                    o_auth_client_id=client_id,
                    o_auth_client_secret=client_secret,
                ),
                environment=env,
            )
        else:
            self._client = None

    @property
    def is_configured(self) -> bool:
        return self._configured

    async def _run_sync(self, func, *args, **kwargs):
        return await asyncio.to_thread(partial(func, *args, **kwargs))

    def _error(self, message: str, **extra) -> Dict[str, Any]:
        return {"status": "error", "provider": self.GATEWAY_NAME, "message": message, **extra}

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
        normalized_currency = normalize_currency(currency, "paypal")
        order_request = OrderRequest(
            intent=CheckoutPaymentIntent.CAPTURE,
            purchase_units=[
                PurchaseUnitRequest(
                    amount=AmountWithBreakdown(
                        currency_code=normalized_currency,
                        value=f"{amount:.2f}",
                    )
                )
            ],
        )
        try:
            result = await self._run_sync(
                self._client.orders.create_order,
                {"body": order_request, "prefer": PREFER_REPRESENTATION}
            )
            if not result.is_success():
                return self._error("Failed to create PayPal order", details=result.errors or {})
            order = result.body
            links = order.links or []
            approval_url = next((l.href for l in links if l.rel in {"approve", "payer-action"}), None)
            status_map = {"COMPLETED": "success", "PAYER_ACTION_REQUIRED": "requires_action", "APPROVED": "requires_action", "CREATED": "requires_action"}
            return {
                "status": status_map.get(order.status, "error"),
                "provider": self.GATEWAY_NAME,
                "amount": amount,
                "currency": normalized_currency,
                "payment_intent_id": order.id,
                "raw_status": order.status,
                **({"approval_url": approval_url} if approval_url else {}),
            }
        except Exception as e:
            return self._error(f"Failed to create PayPal order: {e}")

    async def capture_charge(
        self,
        payment_intent_id: str,
        amount: Optional[float] = None,
        idempotency_key: Optional[str] = None,
        **kwargs
    ) -> Dict[str, Any]:
        if not self._configured:
            return self._error(ERR_NOT_CONFIGURED)
        try:
            result = await self._run_sync(
                self._client.orders.capture_order,
                {"id": payment_intent_id, "prefer": PREFER_REPRESENTATION}
            )
            if not result.is_success():
                return self._error("Failed to capture PayPal order", details=result.errors or {})
            order = result.body
            units = order.purchase_units or []
            first = units[0] if units else None
            payments = first.payments if first else None
            captures = payments.captures if payments else []
            cap = captures[0] if captures else None
            captured_amount = float(cap.amount.value) if cap and cap.amount else amount
            status = "success" if cap and cap.status == "COMPLETED" else "pending"
            return {
                "status": status,
                "provider": self.GATEWAY_NAME,
                "payment_intent_id": payment_intent_id,
                "capture_id": cap.id if cap else None,
                "amount_captured": captured_amount,
                "raw_status": cap.status if cap else order.status,
            }
        except Exception as e:
            return self._error(f"Failed to capture: {e}")

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
        capture_id = charge_id or kwargs.get("capture_id")
        if not capture_id:
            return self._error("capture_id required for PayPal refunds")
        try:
            params = {"capture_id": capture_id, "prefer": PREFER_REPRESENTATION}
            if amount is not None:
                currency = kwargs.get("currency", "USD")
                params["body"] = {"amount": {"value": f"{amount:.2f}", "currency_code": normalize_currency(currency, "paypal")}}
            result = await self._run_sync(self._client.payments.refund_captured_payment, params)
            if not result.is_success():
                return self._error("Failed to refund", details=result.errors or {})
            refund = result.body
            return {
                "status": "success" if refund.status == "COMPLETED" else "pending",
                "provider": self.GATEWAY_NAME,
                "refund_id": refund.id,
                "amount_refunded": float(refund.amount.value) if refund.amount else amount,
                "raw_status": refund.status,
            }
        except Exception as e:
            return self._error(f"Failed to refund: {e}")
