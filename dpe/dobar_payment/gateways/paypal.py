from typing import Dict, Any, Optional

from paypalserversdk.paypal_serversdk_client import PaypalServersdkClient
from paypalserversdk.configuration import Environment
from paypalserversdk.http.auth.o_auth_2 import ClientCredentialsAuthCredentials
from paypalserversdk.models.order_request import OrderRequest
from paypalserversdk.models.purchase_unit_request import PurchaseUnitRequest
from paypalserversdk.models.amount_with_breakdown import AmountWithBreakdown
from paypalserversdk.models.checkout_payment_intent import CheckoutPaymentIntent
from paypalserversdk.models.payment_source import PaymentSource
from paypalserversdk.models.paypal_wallet import PaypalWallet
from paypalserversdk.models.paypal_wallet_experience_context import PaypalWalletExperienceContext
from paypalserversdk.models.paypal_experience_user_action import PaypalExperienceUserAction
from paypalserversdk.models.payee_payment_method_preference import PayeePaymentMethodPreference
from paypalserversdk.models.refund_request import RefundRequest
from paypalserversdk.models.money import Money

from dobar_payment.interfaces import PaymentGateway


class PaypalPaymentGateway(PaymentGateway):
    """PayPal gateway backed by the official PayPal Server SDK.

    This implementation uses the paypal-server-sdk package which handles
    OAuth2 authentication automatically. It creates Orders with intent=CAPTURE
    using the Orders v2 API and normalizes responses for the BarZ payment flow.
    """

    def __init__(self, config: Dict[str, Any]):
        client_id: Optional[str] = config.get("PAYPAL_CLIENT_ID")
        client_secret: Optional[str] = config.get("PAYPAL_CLIENT_SECRET")
        environment_str: str = config.get("PAYPAL_ENV", "sandbox")

        self._credentials_configured = bool(client_id and client_secret)

        # Select environment
        if environment_str == "live":
            environment = Environment.PRODUCTION
        else:
            environment = Environment.SANDBOX

        # Initialize SDK client - handles OAuth automatically
        if self._credentials_configured:
            self._client = PaypalServersdkClient(
                client_credentials_auth_credentials=ClientCredentialsAuthCredentials(
                    o_auth_client_id=client_id,
                    o_auth_client_secret=client_secret,
                ),
                environment=environment,
            )
        else:
            self._client = None

    # ------------------------------------------------------------------
    # Public PaymentGateway interface
    # ------------------------------------------------------------------

    def create_charge(self, amount: float, currency: str, **kwargs) -> Dict[str, Any]:
        """Create a PayPal Order with intent=CAPTURE via Orders v2.

        Flow (wallet / hosted checkout oriented):
        1. Creates Order with intent=CAPTURE.
        2. If PayPal returns PAYER_ACTION_REQUIRED/APPROVED, the client
           must redirect the user to the "approve" / "payer-action" link.
        3. When the front-end later confirms and captures the order,
           a separate endpoint can mark it as paid.
        """
        if not self._credentials_configured or not self._client:
            return {
                "status": "error",
                "provider": "paypal",
                "message": "PayPal credentials not configured",
            }

        normalized_currency = normalize_currency(currency, target="paypal")

        # Build the order request using SDK models
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
            result = self._client.orders.create_order({
                "body": order_request,
                "prefer": "return=representation",
            })

            if not result.is_success():
                return {
                    "status": "error",
                    "provider": "paypal",
                    "message": "Failed to create PayPal order",
                    "details": result.errors if result.errors else {},
                }

            order = result.body
            order_id = order.id
            order_status = order.status
            links = order.links or []

            approval_url: Optional[str] = None
            for link in links:
                if link.rel in {"approve", "payer-action"}:
                    approval_url = link.href
                    break

            # Map PayPal order status to our normalized status
            if order_status == "COMPLETED":
                normalized_status = "success"
            elif order_status in {"PAYER_ACTION_REQUIRED", "APPROVED", "CREATED"}:
                normalized_status = "requires_action"
            else:
                normalized_status = "error"

            response: Dict[str, Any] = {
                "status": normalized_status,
                "provider": "paypal",
                "amount": amount,
                "currency": normalized_currency,
                "payment_intent_id": order_id,
                "raw_status": order_status,
            }

            if approval_url:
                response["approval_url"] = approval_url
            if normalized_status == "error":
                response["details"] = {"order_status": order_status}

            return response

        except Exception as exc:
            return {
                "status": "error",
                "provider": "paypal",
                "message": f"Failed to create PayPal order: {exc}",
            }

    def capture_charge(self, payment_intent_id: str, amount: Optional[float] = None) -> Dict[str, Any]:
        """Capture a previously-created PayPal Order.

        Docs: https://developer.paypal.com/docs/api/orders/v2/#orders_capture
        """
        if not self._credentials_configured or not self._client:
            return {
                "status": "error",
                "provider": "paypal",
                "message": "PayPal credentials not configured",
            }

        try:
            result = self._client.orders.capture_order({
                "id": payment_intent_id,
                "prefer": "return=representation",
            })

            if not result.is_success():
                return {
                    "status": "error",
                    "provider": "paypal",
                    "message": "Failed to capture PayPal order",
                    "details": result.errors if result.errors else {},
                }

            order = result.body
            order_status = order.status
            purchase_units = order.purchase_units or []
            first_unit = purchase_units[0] if purchase_units else None
            payments = first_unit.payments if first_unit else None
            captures = payments.captures if payments else []
            first_capture = captures[0] if captures else None

            capture_id = first_capture.id if first_capture else None
            capture_status = first_capture.status if first_capture else None
            amount_info = first_capture.amount if first_capture else None
            currency_code = amount_info.currency_code if amount_info else "USD"
            value_str = amount_info.value if amount_info else None

            try:
                captured_amount = float(value_str) if value_str is not None else amount
            except (TypeError, ValueError):
                captured_amount = amount

            if capture_status == "COMPLETED":
                normalized_status = "success"
            elif capture_status in {"PENDING", "PARTIALLY_REFUNDED"}:
                normalized_status = "pending"
            else:
                normalized_status = "error"

            response: Dict[str, Any] = {
                "status": normalized_status,
                "provider": "paypal",
                "payment_intent_id": payment_intent_id,
                "charge_id": capture_id,
                "raw_status": capture_status or order_status,
                "currency": currency_code,
                "amount": captured_amount,
            }

            if normalized_status == "error":
                response["details"] = {"capture_status": capture_status, "order_status": order_status}

            return response

        except Exception as exc:
            return {
                "status": "error",
                "provider": "paypal",
                "message": f"Failed to capture PayPal order: {exc}",
            }

    def refund_charge(
        self,
        charge_id: Optional[str] = None,
        payment_intent_id: Optional[str] = None,
        amount: Optional[float] = None,
    ) -> Dict[str, Any]:
        """Refund a PayPal capture using the Payments v2 API.

        For PayPal, ``charge_id`` is treated as the capture_id returned
        from ``capture_charge``. ``payment_intent_id`` is ignored for the
        actual refund call but accepted for interface compatibility.
        """
        if not charge_id and not payment_intent_id:
            return {
                "status": "error",
                "provider": "paypal",
                "message": "Either charge_id or payment_intent_id is required",
            }

        if not self._credentials_configured or not self._client:
            return {
                "status": "error",
                "provider": "paypal",
                "message": "PayPal credentials not configured",
            }

        capture_id = charge_id or ""

        # Build refund request
        refund_request: Optional[RefundRequest] = None
        if amount is not None:
            refund_request = RefundRequest(
                amount=Money(
                    value=f"{amount:.2f}",
                )
            )

        try:
            result = self._client.payments.refund_captured_payment({
                "capture_id": capture_id,
                "prefer": "return=representation",
                "body": refund_request,
            })

            if not result.is_success():
                return {
                    "status": "error",
                    "provider": "paypal",
                    "message": "Failed to refund PayPal capture",
                    "details": result.errors if result.errors else {},
                }

            refund = result.body
            refund_id = refund.id
            amount_info = refund.amount
            currency_code = amount_info.currency_code if amount_info else None
            value_str = amount_info.value if amount_info else None

            try:
                refunded_amount = float(value_str) if value_str is not None else amount
            except (TypeError, ValueError):
                refunded_amount = amount

            return {
                "status": "success",
                "provider": "paypal",
                "refund_id": refund_id,
                "amount_refunded": refunded_amount,
                "currency": currency_code,
            }

        except Exception as exc:
            return {
                "status": "error",
                "provider": "paypal",
                "message": f"Failed to refund PayPal capture: {exc}",
            }

    # ------------------------------------------------------------------
    # Optional hosted checkout / redirect flow
    # ------------------------------------------------------------------

    def create_checkout_session(self, success_url: str, cancel_url: str) -> Dict[str, Any]:
        """Create a PayPal Order optimized for hosted checkout redirect.

        This mirrors the redirect-style flow described in the PayPal Orders
        v2 docs, using payment_source.paypal.experience_context with
        return_url and cancel_url.
        """
        if not self._credentials_configured or not self._client:
            return {
                "status": "error",
                "provider": "paypal",
                "message": "PayPal credentials not configured",
            }

        # Build checkout order with experience context for redirect
        order_request = OrderRequest(
            intent=CheckoutPaymentIntent.CAPTURE,
            purchase_units=[
                PurchaseUnitRequest(
                    amount=AmountWithBreakdown(
                        currency_code="BRL",
                        value="29.90",
                    )
                )
            ],
            payment_source=PaymentSource(
                paypal=PaypalWallet(
                    experience_context=PaypalWalletExperienceContext(
                        payment_method_preference=PayeePaymentMethodPreference.IMMEDIATE_PAYMENT_REQUIRED,
                        user_action=PaypalExperienceUserAction.PAY_NOW,
                        return_url=success_url,
                        cancel_url=cancel_url,
                    )
                )
            ),
        )

        try:
            result = self._client.orders.create_order({
                "body": order_request,
                "prefer": "return=representation",
            })

            if not result.is_success():
                return {
                    "status": "error",
                    "provider": "paypal",
                    "message": "Failed to create PayPal checkout order",
                    "details": result.errors if result.errors else {},
                }

            order = result.body
            order_id = order.id
            order_status = order.status
            links = order.links or []

            approval_url: Optional[str] = None
            for link in links:
                if link.rel in {"approve", "payer-action"}:
                    approval_url = link.href
                    break

            if not approval_url:
                return {
                    "status": "error",
                    "provider": "paypal",
                    "message": "PayPal response did not include an approval URL",
                    "details": {"order_id": order_id, "status": order_status},
                }

            return {
                "status": "success",
                "provider": "paypal",
                "checkout_url": approval_url,
                "order_id": order_id,
                "raw_status": order_status,
            }

        except Exception as exc:
            return {
                "status": "error",
                "provider": "paypal",
                "message": f"Failed to create PayPal checkout order: {exc}",
            }
