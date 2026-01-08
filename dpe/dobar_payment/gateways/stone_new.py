from typing import Dict, Any, Optional, Set
from functools import partial
import asyncio
import os

from dobar_payment.interfaces import PaymentGateway, GatewayCapability
from dobar_payment.pagarme_sdk.pagarmeapisdk.pagarmeapisdk_client import PagarmeapisdkClient
from dobar_payment.pagarme_sdk.pagarmeapisdk.http.auth.basic_auth import BasicAuthCredentials
from dobar_payment.pagarme_sdk.pagarmeapisdk.configuration import Environment
from dobar_payment.pagarme_sdk.pagarmeapisdk.exceptions.error_exception import ErrorException
from dobar_payment.pagarme_sdk.pagarmeapisdk.models.create_order_request import CreateOrderRequest
from dobar_payment.pagarme_sdk.pagarmeapisdk.models.create_order_item_request import CreateOrderItemRequest
from dobar_payment.pagarme_sdk.pagarmeapisdk.models.create_cancel_charge_request import CreateCancelChargeRequest
from dobar_payment.pagarme_sdk.pagarmeapisdk.models.create_customer_request import CreateCustomerRequest
from dobar_payment.pagarme_sdk.pagarmeapisdk.models.create_address_request import CreateAddressRequest
from dobar_payment.pagarme_sdk.pagarmeapisdk.models.create_payment_request import CreatePaymentRequest
from dobar_payment.pagarme_sdk.pagarmeapisdk.models.create_credit_card_payment_request import CreateCreditCardPaymentRequest
from dobar_payment.pagarme_sdk.pagarmeapisdk.models.create_debit_card_payment_request import CreateDebitCardPaymentRequest
from dobar_payment.pagarme_sdk.pagarmeapisdk.models.create_card_request import CreateCardRequest
from dobar_payment.pagarme_sdk.pagarmeapisdk.models.create_pix_payment_request import CreatePixPaymentRequest
from dobar_payment.pagarme_sdk.pagarmeapisdk.models.create_payment_authentication_request import CreatePaymentAuthenticationRequest
from dobar_payment.pagarme_sdk.pagarmeapisdk.models.create_three_d_secure_request import CreateThreeDSecureRequest
from dobar_payment.pagarme_sdk.pagarmeapisdk.models.pix_additional_information import PixAdditionalInformation
from dobar_payment.pagarme_sdk.pagarmeapisdk.models.create_phones_request import CreatePhonesRequest
from dobar_payment.pagarme_sdk.pagarmeapisdk.models.create_phone_request import CreatePhoneRequest

ERR_NOT_CONFIGURED = "Pagar.me credentials not configured"
ERR_CUSTOMER_REQUIRED = "Customer data is required"
ERR_PAYMENT_METHOD_REQUIRED = "Payment method data is required"
ERR_CHARGE_ID_REQUIRED = "charge_id is required"
PAYMENT_METHODS = {"credit_card", "debit_card", "pix"}
MAX_STATEMENT_DESCRIPTOR = 13


def _get_pagarme_client() -> PagarmeapisdkClient:
    username = os.getenv("PAGARME_USERNAME")
    password = os.getenv("PAGARME_PASSWORD", "")
    if not username:
        raise ValueError("PAGARME_USERNAME not configured")
    return PagarmeapisdkClient(
        basic_auth_credentials=BasicAuthCredentials(username=username, password=password),
        environment=Environment.PRODUCTION
    )


class StonePaymentGateway(PaymentGateway):
    GATEWAY_NAME = "stone"
    SUPPORTED_CURRENCIES: Set[str] = {"BRL"}
    CAPABILITIES: Set[GatewayCapability] = {
        GatewayCapability.PIX,
        GatewayCapability.CREDIT_CARD,
        GatewayCapability.DEBIT_CARD,
        GatewayCapability.INSTALLMENTS,
        GatewayCapability.PARTIAL_REFUND,
        GatewayCapability.WEBHOOKS,
    }

    def __init__(self, config: Dict[str, Any]):
        super().__init__(config)
        username = config.get("PAGARME_USERNAME") or os.getenv("PAGARME_USERNAME")
        self._configured = bool(username)
        self._client = None
        if self._configured:
            try:
                self._client = _get_pagarme_client()
            except ValueError:
                self._configured = False

    @property
    def is_configured(self) -> bool:
        return self._configured

    async def _run_sync(self, func, *args, **kwargs):
        return await asyncio.to_thread(partial(func, *args, **kwargs))

    def _error(self, message: str, **extra) -> Dict[str, Any]:
        return {"status": "error", "provider": self.GATEWAY_NAME, "message": message, **extra}

    def _build_phone(self, data: Dict[str, Any]) -> CreatePhoneRequest:
        return CreatePhoneRequest(
            country_code=data.get("country_code", "55"),
            area_code=data.get("area_code", ""),
            number=data.get("number", "")
        )

    def _build_phones(self, phones_data: Optional[Dict[str, Any]]) -> CreatePhonesRequest:
        if not phones_data:
            return CreatePhonesRequest(home_phone=None, mobile_phone=None)
        home = self._build_phone(phones_data["home_phone"]) if "home_phone" in phones_data else None
        mobile = self._build_phone(phones_data["mobile_phone"]) if "mobile_phone" in phones_data else None
        return CreatePhonesRequest(home_phone=home, mobile_phone=mobile)

    def _build_address(self, addr: Optional[Dict[str, Any]]) -> CreateAddressRequest:
        if not addr:
            addr = {}
        return CreateAddressRequest(
            street=addr.get("street", ""), number=addr.get("number", ""),
            zip_code=addr.get("zip_code", ""), neighborhood=addr.get("neighborhood", ""),
            city=addr.get("city", ""), state=addr.get("state", ""),
            country=addr.get("country", "BR"), complement=addr.get("complement", ""),
            line_1=addr.get("line_1", ""), line_2=addr.get("line_2", ""), metadata=addr.get("metadata", {})
        )

    def _build_customer(self, customer: Dict[str, Any]) -> CreateCustomerRequest:
        return CreateCustomerRequest(
            name=customer["name"], email=customer["email"],
            document=customer.get("document", ""),
            mtype=customer.get("type", "individual"),
            address=self._build_address(customer.get("address")),
            metadata=customer.get("metadata", {}),
            phones=self._build_phones(customer.get("phones")),
            code=customer.get("code", customer.get("email", ""))
        )

    def _build_card(self, card: Dict[str, Any]) -> CreateCardRequest:
        return CreateCardRequest(
            number=card.get("number"), holder_name=card.get("holder_name"),
            exp_month=card.get("exp_month"), exp_year=card.get("exp_year"),
            cvv=card.get("cvv"), brand=card.get("brand"),
            holder_document=card.get("holder_document")
        )

    def _build_credit_card(self, pm: Dict[str, Any]) -> CreateCreditCardPaymentRequest:
        card = self._build_card(pm["card"]) if "card" in pm and not pm.get("card_id") and not pm.get("card_token") else None
        desc = pm.get("statement_descriptor", "")[:MAX_STATEMENT_DESCRIPTOR] or None
        return CreateCreditCardPaymentRequest(
            card=card, card_id=pm.get("card_id"), card_token=pm.get("card_token"),
            installments=pm.get("installments", 1), capture=pm.get("capture", True),
            statement_descriptor=desc
        )

    def _build_debit_card(self, pm: Dict[str, Any]) -> CreateDebitCardPaymentRequest:
        card = self._build_card(pm["card"]) if "card" in pm and not pm.get("card_id") and not pm.get("card_token") else None
        auth = None
        if "authentication" in pm:
            a = pm["authentication"]
            tds = None
            if "threed_secure" in a:
                t = a["threed_secure"]
                tds = CreateThreeDSecureRequest(
                    mpi=t.get("mpi"), cavv=t.get("cavv"), eci=t.get("eci"),
                    transaction_id=t.get("transaction_id"),
                    ds_transaction_id=t.get("ds_transaction_id"), version=t.get("version")
                )
            auth = CreatePaymentAuthenticationRequest(mtype=a.get("type", "threed_secure"), threed_secure=tds)
        desc = pm.get("statement_descriptor", "")[:MAX_STATEMENT_DESCRIPTOR] or None
        return CreateDebitCardPaymentRequest(
            card=card, card_id=pm.get("card_id"), card_token=pm.get("card_token"),
            authentication=auth, statement_descriptor=desc
        )

    def _build_pix(self, pm: Dict[str, Any]) -> CreatePixPaymentRequest:
        kwargs = {}
        if "expires_in" in pm:
            kwargs["expires_in"] = pm["expires_in"]
        if "expires_at" in pm:
            kwargs["expires_at"] = pm["expires_at"]
        if "additional_information" in pm:
            kwargs["additional_information"] = [
                PixAdditionalInformation(name=i.get("name", ""), value=i.get("value", ""))
                for i in pm["additional_information"]
            ]
        return CreatePixPaymentRequest(**kwargs)

    def _build_payment(self, pm: Dict[str, Any], amount: int) -> CreatePaymentRequest:
        method = pm.get("payment_method", "credit_card")
        if method == "pix":
            return CreatePaymentRequest(payment_method="pix", pix=self._build_pix(pm), amount=amount)
        if method == "debit_card":
            return CreatePaymentRequest(payment_method="debit_card", debit_card=self._build_debit_card(pm), amount=amount)
        return CreatePaymentRequest(payment_method="credit_card", credit_card=self._build_credit_card(pm), amount=amount)

    def _normalize_order(self, response: Any, method: str) -> Dict[str, Any]:
        result = {
            "status": "success", "provider": self.GATEWAY_NAME,
            "order_id": getattr(response, "id", None),
            "order_code": getattr(response, "code", None),
            "order_status": getattr(response, "status", None),
            "amount": getattr(response, "amount", None),
            "currency": "BRL", "payment_method": method,
            "created_at": getattr(response, "created_at", None),
        }
        charges = getattr(response, "charges", None)
        if charges and len(charges) > 0:
            charge = charges[0]
            result["charge_id"] = getattr(charge, "id", None)
            result["charge_status"] = getattr(charge, "status", None)
            tx = getattr(charge, "last_transaction", None)
            if tx:
                result["transaction_id"] = getattr(tx, "id", None)
                result["transaction_status"] = getattr(tx, "status", None)
                if method == "pix":
                    result["qr_code"] = getattr(tx, "qr_code", None)
                    result["qr_code_url"] = getattr(tx, "qr_code_url", None)
                    result["pix_copia_e_cola"] = getattr(tx, "qr_code", None)
                    result["expires_at"] = getattr(tx, "expires_at", None)
                if method in ("credit_card", "debit_card"):
                    result["acquirer_message"] = getattr(tx, "acquirer_message", None)
                    result["acquirer_return_code"] = getattr(tx, "acquirer_return_code", None)
        return result

    def _normalize_charge(self, response: Any, method: str) -> Dict[str, Any]:
        result = {
            "status": "success", "provider": self.GATEWAY_NAME,
            "charge_id": getattr(response, "id", None),
            "charge_status": getattr(response, "status", None),
            "amount": getattr(response, "amount", None),
            "currency": "BRL", "payment_method": method,
            "created_at": getattr(response, "created_at", None),
        }
        tx = getattr(response, "last_transaction", None)
        if tx:
            result["transaction_id"] = getattr(tx, "id", None)
            result["transaction_status"] = getattr(tx, "status", None)
            if method == "pix":
                result["qr_code"] = getattr(tx, "qr_code", None)
                result["qr_code_url"] = getattr(tx, "qr_code_url", None)
                result["pix_copia_e_cola"] = getattr(tx, "qr_code", None)
                result["expires_at"] = getattr(tx, "expires_at", None)
            if method in ("credit_card", "debit_card"):
                result["acquirer_message"] = getattr(tx, "acquirer_message", None)
                result["acquirer_return_code"] = getattr(tx, "acquirer_return_code", None)
        return result

    async def create_charge(
        self, amount: float, currency: str,
        customer: Optional[Dict[str, Any]] = None,
        payment_method: Optional[Dict[str, Any]] = None,
        idempotency_key: Optional[str] = None, **kwargs
    ) -> Dict[str, Any]:
        if not self._configured or not self._client:
            return self._error(ERR_NOT_CONFIGURED)
        if not customer:
            return self._error(ERR_CUSTOMER_REQUIRED)
        if not payment_method:
            return self._error(ERR_PAYMENT_METHOD_REQUIRED)
        method = payment_method.get("payment_method", "credit_card")
        if method not in PAYMENT_METHODS:
            return self._error(f"Unsupported payment method: {method}")
        amount_cents = int(amount * 100)
        try:
            customer_model = self._build_customer(customer)
            payment_model = self._build_payment(payment_method, amount_cents)
            order_code = kwargs.get("order_id", f"order_{os.urandom(8).hex()}")
            order_item = CreateOrderItemRequest(
                amount=amount_cents, description=kwargs.get("description", "Payment"),
                quantity=1, category=kwargs.get("category", "payment")
            )
            order_request = CreateOrderRequest(
                items=[order_item], customer=customer_model,
                payments=[payment_model], code=order_code, closed=True
            )
            response = await self._run_sync(self._client.orders.create_order, order_request)
            return self._normalize_order(response, method)
        except ErrorException as e:
            return self._error(str(e), errors=getattr(e, "errors", None))
        except Exception as e:
            return self._error(f"Unexpected error: {e}")

    async def refund_charge(
        self, charge_id: Optional[str] = None,
        payment_intent_id: Optional[str] = None,
        amount: Optional[float] = None,
        idempotency_key: Optional[str] = None, **kwargs
    ) -> Dict[str, Any]:
        if not self._configured or not self._client:
            return self._error(ERR_NOT_CONFIGURED)
        if not charge_id:
            return self._error(ERR_CHARGE_ID_REQUIRED)
        try:
            cancel_request = CreateCancelChargeRequest(amount=int(amount * 100)) if amount else CreateCancelChargeRequest()
            response = await self._run_sync(self._client.charges.cancel_charge, charge_id, cancel_request)
            return {
                "status": "success", "provider": self.GATEWAY_NAME,
                "refund_id": getattr(response, "id", None), "charge_id": charge_id,
                "amount_refunded": getattr(response, "canceled_amount", getattr(response, "amount", None)),
                "charge_status": getattr(response, "status", None),
            }
        except ErrorException as e:
            return self._error(str(e), errors=getattr(e, "errors", None))
        except Exception as e:
            return self._error(f"Unexpected error: {e}")

    async def capture_charge(
        self, payment_intent_id: str,
        amount: Optional[float] = None,
        idempotency_key: Optional[str] = None, **kwargs
    ) -> Dict[str, Any]:
        if not self._configured or not self._client:
            return self._error(ERR_NOT_CONFIGURED)
        if not payment_intent_id:
            return self._error(ERR_CHARGE_ID_REQUIRED)
        try:
            capture_kwargs = {"amount": int(amount * 100)} if amount else None
            response = await self._run_sync(
                self._client.charges.capture_charge,
                charge_id=payment_intent_id, request=capture_kwargs
            )
            return {
                "status": "success", "provider": self.GATEWAY_NAME,
                "charge_id": getattr(response, "id", None),
                "charge_status": getattr(response, "status", None),
                "amount_captured": getattr(response, "amount", None),
            }
        except ErrorException as e:
            return self._error(str(e))
        except Exception as e:
            return self._error(f"Unexpected error: {e}")

    async def get_charge(self, charge_id: str, **kwargs) -> Dict[str, Any]:
        if not self._configured or not self._client:
            return self._error(ERR_NOT_CONFIGURED)
        try:
            response = await self._run_sync(self._client.charges.get_charge, charge_id)
            method = getattr(response, "payment_method", "unknown")
            return self._normalize_charge(response, method)
        except ErrorException as e:
            return self._error(str(e))
        except Exception as e:
            return self._error(f"Unexpected error: {e}")
