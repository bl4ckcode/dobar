# This module is internal and should not be imported directly.
# Use `get_payment_gateway()` from `factory.py` instead.
"""
Stone/Pagar.me Payment Gateway Implementation.

Supports:
- Credit Card: Full support with installments, auth_only, auth_and_capture
- Debit Card: Requires 3DS authentication (threed_secure object)
- PIX: Brazilian instant payment with QR code generation

Reference: https://docs.pagar.me/reference/introducao-1
"""

from typing import Dict, Any, Optional
from dobar_payment.interfaces import PaymentGateway

# Initialize pagarme_sdk path fix before importing SDK modules
import dobar_payment.pagarme_sdk


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

from dotenv import load_dotenv

import os
import logging

load_dotenv()

logger = logging.getLogger(__name__)


def _get_pagarme_client(environment: str = "production") -> PagarmeapisdkClient:
    """Initialize Pagar.me SDK client with credentials from environment.
    
    Args:
        environment: "production" or "sandbox" (informational only - 
                     Pagar.me uses the same URL for both; sandbox/production 
                     is determined by API key type: sk_test_* for sandbox)
        
    Returns:
        Configured PagarmeapisdkClient instance
        
    Raises:
        ValueError: If PAGARME_USERNAME is not configured
    """
    username = os.getenv('PAGARME_USERNAME')
    password = os.getenv('PAGARME_PASSWORD', '')

    if not username:
        raise ValueError("Pagar.me API key (PAGARME_USERNAME) is missing in environment.")

    # Pagar.me uses a single API endpoint (api.pagar.me/core/v5) for both sandbox and production.
    # The environment is determined by the API key type:
    # - sk_test_* keys work in sandbox mode
    # - sk_* keys (without 'test') work in production mode
    # So we always use Environment.PRODUCTION (the only defined value in the SDK)

    return PagarmeapisdkClient(
        basic_auth_credentials=BasicAuthCredentials(
            username=username,
            password=password
        ),
        environment=Environment.PRODUCTION
    )

class StonePaymentGateway(PaymentGateway):
    """Stone/Pagar.me Payment Gateway.
    
    Supports three payment methods for the Brazilian market:
    - credit_card: With installments (1-12), auth_only or auth_and_capture
    - debit_card: Requires 3DS authentication (Gateway customers only)
    - pix: Brazilian instant payment with QR code
    
    Configuration:
        config["PAGARME_USERNAME"]: API key (secret key)
        config["PAGARME_PASSWORD"]: Optional password (usually empty)
        config["PAGARME_ENV"]: "sandbox" or "production" (default: production)
    """

    # Supported payment methods
    PAYMENT_METHODS = {"credit_card", "debit_card", "pix"}
    
    # Max statement descriptor length (PSP mode)
    MAX_STATEMENT_DESCRIPTOR_LENGTH = 13

    def __init__(self, config: Dict[str, Any]):
        """Initialize Stone gateway with configuration.
        
        Args:
            config: Dictionary with PAGARME_USERNAME, PAGARME_PASSWORD, PAGARME_ENV
        """
        self._environment = config.get("PAGARME_ENV", "production")
        
        # Check if credentials are available
        username = config.get("PAGARME_USERNAME") or os.getenv("PAGARME_USERNAME")
        self._credentials_configured = bool(username)
        
        if self._credentials_configured:
            try:
                self._client = _get_pagarme_client(self._environment)
            except ValueError as e:
                logger.warning(f"Pagar.me client initialization failed: {e}")
                self._client = None
                self._credentials_configured = False
        else:
            self._client = None

    def create_charge(
        self, 
        amount: float, 
        currency: str, 
        customer: Optional[Dict[str, Any]] = None,
        payment_method: Optional[Dict[str, Any]] = None,
        **kwargs
    ) -> Dict[str, Any]:
        """Create a Stone/Pagar.me charge.

        Supports credit_card, debit_card, and pix payment methods.
        
        Args:
            amount: Amount in BRL (will be converted to cents)
            currency: Currency code (should be BRL for Pagar.me)
            customer: Customer data with name, email, document, phones
            payment_method: Payment details including:
                - payment_method: "credit_card", "debit_card", or "pix"
                - For cards: card object with number, holder_name, exp_month, exp_year, cvv
                - For credit_card: installments (1-12), capture (bool)
                - For debit_card: authentication (3DS data required)
                - For pix: expires_in (seconds), additional_information
            **kwargs: Additional parameters (order_id, metadata, etc.)
            
        Returns:
            Dictionary with charge result including:
            - status: "success" or "error"
            - charge_id: Pagar.me charge ID
            - For PIX: qr_code, qr_code_url, pix_copia_e_cola
        """
        if not self._credentials_configured or not self._client:
            return {
                "status": "error",
                "provider": "stone",
                "message": "Pagar.me credentials not configured",
            }

        if not customer:
            return {
                "status": "error",
                "provider": "stone", 
                "message": "Customer data is required",
            }

        if not payment_method:
            return {
                "status": "error",
                "provider": "stone",
                "message": "Payment method data is required",
            }

        method = payment_method.get("payment_method", "credit_card")
        if method not in self.PAYMENT_METHODS:
            return {
                "status": "error",
                "provider": "stone",
                "message": f"Unsupported payment method: {method}. Supported: {self.PAYMENT_METHODS}",
            }

        # Convert amount to cents (Pagar.me expects integer cents)
        amount_cents = int(amount * 100)

        try:
            customer_model = self._build_customer_model(customer)
            payment_model = self._build_payment_model(payment_method, amount_cents)
            
            order_code = kwargs.get("order_id", f"order_{os.urandom(8).hex()}")
            
            # Create order item representing the purchase
            order_item = CreateOrderItemRequest(
                amount=amount_cents,
                description=kwargs.get("description", "Payment"),
                quantity=1,
                category=kwargs.get("category", "payment")
            )
            
            # Pagar.me V5 uses orders.create_order() with payments array
            # Setting closed=True will automatically process the payment
            order_request = CreateOrderRequest(
                items=[order_item],
                customer=customer_model,
                payments=[payment_model],
                code=order_code,
                closed=True
            )

            response = self._client.orders.create_order(order_request)
            
            return self._normalize_order_response(response, method)

        except ErrorException as e:
            logger.error(f"Pagar.me API error creating charge: {e}")
            return {
                "status": "error",
                "provider": "stone",
                "message": str(e),
                "errors": getattr(e, 'errors', None),
            }
        except Exception as e:
            logger.error(f"Unexpected error creating charge: {e}")
            return {
                "status": "error",
                "provider": "stone",
                "message": f"Unexpected error: {str(e)}",
            }

    def _build_customer_model(self, customer: Dict[str, Any]) -> CreateCustomerRequest:
        """Build customer model from customer data.
        
        PIX payments require complete customer data including phone numbers.
        
        Pagar.me requires:
        - name, email, document, mtype (type), address, metadata, phones, code
        
        For flexibility, we use sensible defaults for optional fields the caller doesn't provide.
        """
        # Build phones
        phones = None
        if "phones" in customer:
            phones_data = customer["phones"]
            home_phone = None
            mobile_phone = None
            
            if "home_phone" in phones_data:
                hp = phones_data["home_phone"]
                home_phone = CreatePhoneRequest(
                    country_code=hp.get("country_code", "55"),
                    area_code=hp.get("area_code", ""),
                    number=hp.get("number", "")
                )
            
            if "mobile_phone" in phones_data:
                mp = phones_data["mobile_phone"]
                mobile_phone = CreatePhoneRequest(
                    country_code=mp.get("country_code", "55"),
                    area_code=mp.get("area_code", ""),
                    number=mp.get("number", "")
                )
            
            phones = CreatePhonesRequest(
                home_phone=home_phone,
                mobile_phone=mobile_phone
            )
        else:
            # Default phones object if not provided
            phones = CreatePhonesRequest(home_phone=None, mobile_phone=None)

        # Build address
        address = None
        if "address" in customer:
            addr = customer["address"]
            address = CreateAddressRequest(
                street=addr.get("street", ""),
                number=addr.get("number", ""),
                zip_code=addr.get("zip_code", ""),
                neighborhood=addr.get("neighborhood", ""),
                city=addr.get("city", ""),
                state=addr.get("state", ""),
                country=addr.get("country", "BR"),
                complement=addr.get("complement", ""),
                line_1=addr.get("line_1", ""),
                line_2=addr.get("line_2", ""),
                metadata=addr.get("metadata", {})
            )
        else:
            # Default empty address - Pagar.me requires this field
            address = CreateAddressRequest(
                street="",
                number="",
                zip_code="",
                neighborhood="",
                city="",
                state="",
                country="BR",
                complement="",
                line_1="",
                line_2="",
                metadata={}
            )

        # Customer type: 'individual' or 'company'
        mtype = customer.get("type", "individual")
        
        # Customer code - use email or generate if not provided
        code = customer.get("code", customer.get("email", ""))
        
        # Metadata
        metadata = customer.get("metadata", {})

        return CreateCustomerRequest(
            name=customer["name"],
            email=customer["email"],
            document=customer.get("document", ""),
            mtype=mtype,
            address=address,
            metadata=metadata,
            phones=phones,
            code=code
        )

    def _build_card_model(self, card_data: Dict[str, Any]) -> CreateCardRequest:
        """Build card request model from card data."""
        return CreateCardRequest(
            number=card_data.get("number"),
            holder_name=card_data.get("holder_name"),
            exp_month=card_data.get("exp_month"),
            exp_year=card_data.get("exp_year"),
            cvv=card_data.get("cvv"),
            brand=card_data.get("brand"),
            holder_document=card_data.get("holder_document")
        )

    def _build_credit_card_model(self, payment_method: Dict[str, Any]) -> CreateCreditCardPaymentRequest:
        """Build credit card payment request.
        
        Supports:
        - card: Raw card data (number, holder_name, exp_month, exp_year, cvv)
        - card_id: Stored card ID
        - card_token: Tokenized card from frontend
        - installments: 1-12
        - capture: True for auth_and_capture, False for auth_only
        - statement_descriptor: Max 13 chars (PSP mode)
        """
        card = None
        card_id = payment_method.get("card_id")
        card_token = payment_method.get("card_token")
        
        if "card" in payment_method and not card_id and not card_token:
            card = self._build_card_model(payment_method["card"])
        
        statement_descriptor = payment_method.get("statement_descriptor", "")
        if len(statement_descriptor) > self.MAX_STATEMENT_DESCRIPTOR_LENGTH:
            statement_descriptor = statement_descriptor[:self.MAX_STATEMENT_DESCRIPTOR_LENGTH]

        return CreateCreditCardPaymentRequest(
            card=card,
            card_id=card_id,
            card_token=card_token,
            installments=payment_method.get("installments", 1),
            capture=payment_method.get("capture", True),
            statement_descriptor=statement_descriptor if statement_descriptor else None
        )

    def _build_pix_model(self, payment_method: Dict[str, Any]) -> CreatePixPaymentRequest:
        """Build a Pix payment model.

        Pix payments return a QR code that the customer scans to complete payment.
        
        Args:
            payment_method: Dict with optional keys:
                - expires_in: Seconds until PIX expires (default varies by provider)
                - expires_at: Datetime when PIX expires (RFC3339)
                - additional_information: List of {name, value} dicts for PIX receipt
        """
        pix_kwargs = {}
        
        if "expires_in" in payment_method:
            pix_kwargs["expires_in"] = payment_method["expires_in"]
        if "expires_at" in payment_method:
            pix_kwargs["expires_at"] = payment_method["expires_at"]
            
        # Build additional_information if provided
        if "additional_information" in payment_method:
            additional_info = []
            for item in payment_method["additional_information"]:
                additional_info.append(
                    PixAdditionalInformation(
                        name=item.get("name", ""),
                        value=item.get("value", "")
                    )
                )
            if additional_info:
                pix_kwargs["additional_information"] = additional_info

        return CreatePixPaymentRequest(**pix_kwargs)

    def _build_debit_card_model(self, payment_method: Dict[str, Any]) -> CreateDebitCardPaymentRequest:
        """Build debit card payment request.
        
        IMPORTANT: Debit card requires 3DS authentication (Gateway customers only).
        The 3DS authentication must be performed externally before calling this method.
        
        Args:
            payment_method: Dict with:
                - card: Raw card data OR card_id OR card_token
                - authentication: 3DS authentication data (REQUIRED)
                    - type: Authentication type (e.g., "threed_secure")
                    - threed_secure: {mpi, cavv, eci, transaction_id, ds_transaction_id, version}
                - statement_descriptor: Max 13 chars
        """
        card = None
        card_id = payment_method.get("card_id")
        card_token = payment_method.get("card_token")
        
        if "card" in payment_method and not card_id and not card_token:
            card = self._build_card_model(payment_method["card"])

        # Build 3DS authentication (required for debit)
        authentication = None
        auth_data = payment_method.get("authentication")
        if auth_data:
            threed_secure = None
            if "threed_secure" in auth_data:
                tds = auth_data["threed_secure"]
                threed_secure = CreateThreeDSecureRequest(
                    mpi=tds.get("mpi"),
                    cavv=tds.get("cavv"),
                    eci=tds.get("eci"),
                    transaction_id=tds.get("transaction_id"),
                    ds_transaction_id=tds.get("ds_transaction_id"),
                    version=tds.get("version")
                )
            authentication = CreatePaymentAuthenticationRequest(
                mtype=auth_data.get("type", "threed_secure"),
                threed_secure=threed_secure
            )
        
        statement_descriptor = payment_method.get("statement_descriptor", "")
        if len(statement_descriptor) > self.MAX_STATEMENT_DESCRIPTOR_LENGTH:
            statement_descriptor = statement_descriptor[:self.MAX_STATEMENT_DESCRIPTOR_LENGTH]

        return CreateDebitCardPaymentRequest(
            card=card,
            card_id=card_id,
            card_token=card_token,
            authentication=authentication,
            statement_descriptor=statement_descriptor if statement_descriptor else None
        )

    def _build_payment_model(self, payment_method: Dict[str, Any], amount: int) -> CreatePaymentRequest:
        """Build payment request model based on payment method type.
        
        Args:
            payment_method: Payment data including payment_method type
            amount: Amount in cents
            
        Returns:
            CreatePaymentRequest configured for the specific payment method
        """
        method = payment_method.get("payment_method", "credit_card")

        if method == "pix":
            pix = self._build_pix_model(payment_method)
            return CreatePaymentRequest(
                payment_method="pix",
                pix=pix,
                amount=amount
            )

        if method == "debit_card":
            debit_card = self._build_debit_card_model(payment_method)
            return CreatePaymentRequest(
                payment_method="debit_card",
                debit_card=debit_card,
                amount=amount
            )

        # Default to credit card
        credit_card = self._build_credit_card_model(payment_method)
        return CreatePaymentRequest(
            payment_method="credit_card",
            credit_card=credit_card,
            amount=amount
        )

    def _normalize_order_response(self, response: Any, payment_method: str) -> Dict[str, Any]:
        """Normalize Pagar.me order response to standard format.
        
        When creating an order with closed=True, the payment is processed automatically.
        The order response contains charges array with the payment results.
        
        Args:
            response: Raw Pagar.me order API response (GetOrderResponse)
            payment_method: The payment method used (credit_card, debit_card, pix)
            
        Returns:
            Normalized dictionary with charge details
        """
        result = {
            "status": "success",
            "provider": "stone",
            "order_id": getattr(response, "id", None),
            "order_code": getattr(response, "code", None),
            "order_status": getattr(response, "status", None),
            "amount": getattr(response, "amount", None),
            "currency": "BRL",
            "payment_method": payment_method,
            "created_at": getattr(response, "created_at", None),
        }

        # Extract charge info from the order
        charges = getattr(response, "charges", None)
        if charges and len(charges) > 0:
            charge = charges[0]  # Get the first charge
            result["charge_id"] = getattr(charge, "id", None)
            result["charge_status"] = getattr(charge, "status", None)
            
            # Extract transaction info
            last_transaction = getattr(charge, "last_transaction", None)
            if last_transaction:
                result["transaction_id"] = getattr(last_transaction, "id", None)
                result["transaction_status"] = getattr(last_transaction, "status", None)
                
                # For PIX, extract QR code data
                if payment_method == "pix":
                    result["qr_code"] = getattr(last_transaction, "qr_code", None)
                    result["qr_code_url"] = getattr(last_transaction, "qr_code_url", None)
                    result["pix_copia_e_cola"] = getattr(last_transaction, "qr_code", None)
                    result["expires_at"] = getattr(last_transaction, "expires_at", None)
                
                # For cards, extract additional info
                if payment_method in ("credit_card", "debit_card"):
                    result["acquirer_message"] = getattr(last_transaction, "acquirer_message", None)
                    result["acquirer_return_code"] = getattr(last_transaction, "acquirer_return_code", None)

        return result

    def _normalize_charge_response(self, response: Any, payment_method: str) -> Dict[str, Any]:
        """Normalize Pagar.me charge response to standard format.
        
        Args:
            response: Raw Pagar.me API response
            payment_method: The payment method used (credit_card, debit_card, pix)
            
        Returns:
            Normalized dictionary with charge details
        """
        result = {
            "status": "success",
            "provider": "stone",
            "charge_id": getattr(response, "id", None),
            "charge_status": getattr(response, "status", None),
            "amount": getattr(response, "amount", None),
            "currency": "BRL",
            "payment_method": payment_method,
            "created_at": getattr(response, "created_at", None),
        }

        # Extract transaction info if available
        last_transaction = getattr(response, "last_transaction", None)
        if last_transaction:
            result["transaction_id"] = getattr(last_transaction, "id", None)
            result["transaction_status"] = getattr(last_transaction, "status", None)
            
            # For PIX, extract QR code data
            if payment_method == "pix":
                result["qr_code"] = getattr(last_transaction, "qr_code", None)
                result["qr_code_url"] = getattr(last_transaction, "qr_code_url", None)
                # Some responses have pix_copia_e_cola (copy-paste code)
                result["pix_copia_e_cola"] = getattr(last_transaction, "qr_code", None)
                result["expires_at"] = getattr(last_transaction, "expires_at", None)
            
            # For cards, extract additional info
            if payment_method in ("credit_card", "debit_card"):
                result["acquirer_message"] = getattr(last_transaction, "acquirer_message", None)
                result["acquirer_return_code"] = getattr(last_transaction, "acquirer_return_code", None)

        return result

    def refund_charge(
        self,
        charge_id: Optional[str] = None,
        payment_intent_id: Optional[str] = None,
        amount: Optional[float] = None
    ) -> Dict[str, Any]:
        """Refund a Pagar.me charge (full or partial).
        
        Args:
            charge_id: The Pagar.me charge ID to refund (required)
            payment_intent_id: Not used for Stone, ignored
            amount: Amount to refund in BRL. If None, full refund.
            
        Returns:
            Dictionary with refund result
        """
        if not self._credentials_configured or not self._client:
            return {
                "status": "error",
                "provider": "stone",
                "message": "Pagar.me credentials not configured",
            }

        if not charge_id:
            return {
                "status": "error",
                "provider": "stone",
                "message": "Stone requires a charge_id to refund.",
            }

        try:
            cancel_request = None
            if amount is not None:
                # Partial refund - convert to cents
                amount_cents = int(amount * 100)
                cancel_request = CreateCancelChargeRequest(amount=amount_cents)
            else:
                cancel_request = CreateCancelChargeRequest()

            response = self._client.charges.cancel_charge(charge_id, cancel_request)
            
            return {
                "status": "success",
                "provider": "stone",
                "refund_id": getattr(response, "id", None),
                "charge_id": charge_id,
                "amount_refunded": getattr(response, "canceled_amount", getattr(response, "amount", None)),
                "charge_status": getattr(response, "status", None),
            }

        except ErrorException as e:
            logger.error(f"Pagar.me API error refunding charge {charge_id}: {e}")
            return {
                "status": "error",
                "provider": "stone",
                "message": str(e),
                "errors": getattr(e, 'errors', None),
            }
        except Exception as e:
            logger.error(f"Unexpected error refunding charge {charge_id}: {e}")
            return {
                "status": "error",
                "provider": "stone",
                "message": f"Unexpected error: {str(e)}",
            }

    def capture_charge(
        self,
        payment_intent_id: str,
        amount: Optional[float] = None,
    ) -> Dict[str, Any]:
        """Capture a previously authorized charge.
        
        Use this when create_charge was called with capture=False (auth_only).
        
        Args:
            payment_intent_id: The charge ID to capture
            amount: Amount to capture in BRL. If None, captures full amount.
            
        Returns:
            Dictionary with capture result
        """
        if not self._credentials_configured or not self._client:
            return {
                "status": "error",
                "provider": "stone",
                "message": "Pagar.me credentials not configured",
            }

        if not payment_intent_id:
            return {
                "status": "error",
                "provider": "stone",
                "message": "charge_id (payment_intent_id) is required to capture.",
            }

        try:
            # Pagar.me uses capture_charge endpoint
            capture_kwargs = {}
            if amount is not None:
                capture_kwargs["amount"] = int(amount * 100)

            response = self._client.charges.capture_charge(
                charge_id=payment_intent_id,
                request=capture_kwargs if capture_kwargs else None
            )
            
            return {
                "status": "success",
                "provider": "stone",
                "charge_id": getattr(response, "id", None),
                "charge_status": getattr(response, "status", None),
                "amount_captured": getattr(response, "amount", None),
            }

        except ErrorException as e:
            logger.error(f"Pagar.me API error capturing charge {payment_intent_id}: {e}")
            return {
                "status": "error",
                "provider": "stone",
                "message": str(e),
            }
        except Exception as e:
            logger.error(f"Unexpected error capturing charge {payment_intent_id}: {e}")
            return {
                "status": "error",
                "provider": "stone",
                "message": f"Unexpected error: {str(e)}",
            }

    def get_charge(self, charge_id: str) -> Dict[str, Any]:
        """Retrieve a charge by ID.
        
        Args:
            charge_id: The Pagar.me charge ID
            
        Returns:
            Dictionary with charge details
        """
        if not self._credentials_configured or not self._client:
            return {
                "status": "error",
                "provider": "stone",
                "message": "Pagar.me credentials not configured",
            }

        try:
            response = self._client.charges.get_charge(charge_id)
            
            payment_method = "unknown"
            if hasattr(response, "payment_method"):
                payment_method = response.payment_method
            
            return self._normalize_charge_response(response, payment_method)

        except ErrorException as e:
            logger.error(f"Pagar.me API error getting charge {charge_id}: {e}")
            return {
                "status": "error",
                "provider": "stone",
                "message": str(e),
            }
        except Exception as e:
            logger.error(f"Unexpected error getting charge {charge_id}: {e}")
            return {
                "status": "error",
                "provider": "stone",
                "message": f"Unexpected error: {str(e)}",
            }
