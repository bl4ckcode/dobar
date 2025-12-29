# This module is internal and should not be imported directly.
# Use `get_payment_gateway()` from `factory.py` instead.
"""
Stripe Payment Gateway Implementation.

Stripe is used for Latin American markets (except Brazil, which uses Stone/Pagar.me).

Supports:
- Credit/Debit Cards: Via PaymentIntents with automatic confirmation
- Checkout Sessions: Stripe-hosted checkout page
- SetupIntents: Save cards for future use
- Refunds: Full and partial

Reference: https://docs.stripe.com/api
SDK: https://github.com/stripe/stripe-python (v14+)
"""

from typing import Dict, Any, Optional, List
import logging
import os

from stripe import StripeClient
from stripe._error import StripeError

from app.payment.core.interfaces import PaymentGateway
from app.payment.utils.currency import normalize_currency

logger = logging.getLogger(__name__)

class StripePaymentGateway(PaymentGateway):
    """Stripe Payment Gateway for Latin American markets (except Brazil).
    
    Uses the official Stripe Python SDK v14+ with StripeClient pattern.
    
    Supported payment methods:
    - card: Credit and debit cards (Visa, Mastercard, Amex, etc.)
    - Checkout Sessions: Stripe-hosted payment page
    - SetupIntents: Save payment methods for future use
    
    Configuration:
        config["STRIPE_API_KEY"]: Secret API key (sk_test_... or sk_live_...)
        config["STRIPE_ENV"]: "sandbox" or "live" (for logging purposes)
    """

    # Stripe test card numbers for different scenarios
    TEST_CARDS = {
        "success": "4242424242424242",
        "visa": "4242424242424242",
        "mastercard": "5555555555554444",
        "amex": "378282246310005",
        "declined": "4000000000000002",
        "insufficient_funds": "4000000000009995",
        "requires_auth": "4000002760003184",
        "argentina": "4000000320000021",
        "mexico": "4000004840008001",
        "chile": "4000001520000001",
        "colombia": "4000001700000003",
    }

    def __init__(self, config: Dict[str, Any]):
        """Initialize Stripe gateway with configuration.
        
        Args:
            config: Dictionary with STRIPE_API_KEY and optional STRIPE_ENV
        """
        api_key = config.get("STRIPE_API_KEY") or os.getenv("STRIPE_API_KEY")
        self._environment = config.get("STRIPE_ENV", "sandbox")
        self._credentials_configured = bool(api_key)
        
        if self._credentials_configured:
            # Use the new StripeClient pattern (v8+)
            self._client = StripeClient(api_key)
        else:
            self._client = None
            logger.warning("Stripe API key not configured")

    def create_charge(
        self,
        amount: float,
        currency: str,
        customer: Optional[Dict[str, Any]] = None,
        payment_method: Optional[Dict[str, Any]] = None,
        **kwargs
    ) -> Dict[str, Any]:
        """Create a Stripe PaymentIntent and confirm it.

        Args:
            amount: Amount to charge (will be converted to cents)
            currency: Currency code (USD, MXN, ARS, etc.)
            customer: Customer data with optional stripe_customer_id, email
            payment_method: Payment method data with:
                - payment_method_id: Stripe PaymentMethod ID (pm_...)
                - payment_method: Alternative key for payment_method_id
            **kwargs: Additional parameters (metadata, etc.)
            
        Returns:
            Dictionary with:
            - status: "success", "requires_action", or "error"
            - payment_intent_id: Stripe PaymentIntent ID
            - client_secret: For frontend confirmation if needed
        """
        if not self._credentials_configured or not self._client:
            return {
                "status": "error",
                "provider": "stripe",
                "message": "Stripe API key not configured",
            }

        customer_data = customer or {}
        payment_method_data = payment_method or {}

        # Get payment method ID from either key
        payment_method_id = (
            payment_method_data.get("payment_method_id") or 
            payment_method_data.get("payment_method")
        )
        
        if not payment_method_id:
            return {
                "status": "error",
                "provider": "stripe",
                "message": "payment_method_id is required",
            }

        # Convert amount to cents
        amount_cents = int(amount * 100)
        normalized_currency = normalize_currency(currency, target="stripe")

        try:
            # Build PaymentIntent parameters
            intent_params = {
                "amount": amount_cents,
                "currency": normalized_currency,
                "payment_method": payment_method_id,
                "confirm": True,
                "return_url": kwargs.get("return_url", "https://barz.app/payment/return"),
            }

            # Optional: attach to customer
            customer_id = customer_data.get("stripe_customer_id")
            if customer_id:
                intent_params["customer"] = customer_id

            # Optional: receipt email
            if customer_data.get("email"):
                intent_params["receipt_email"] = customer_data["email"]

            # Optional: metadata
            if kwargs.get("metadata"):
                intent_params["metadata"] = kwargs["metadata"]

            # Optional: description
            if kwargs.get("description"):
                intent_params["description"] = kwargs["description"]

            # Create and confirm the PaymentIntent using StripeClient v1 namespace
            intent = self._client.v1.payment_intents.create(intent_params)

            return self._normalize_payment_intent_response(intent)

        except StripeError as e:
            logger.error(f"Stripe API error creating charge: {e}")
            return {
                "status": "error",
                "provider": "stripe",
                "message": str(e.user_message) if hasattr(e, 'user_message') else str(e),
                "code": getattr(e, 'code', None),
            }
        except Exception as e:
            logger.error(f"Unexpected error creating charge: {e}")
            return {
                "status": "error",
                "provider": "stripe",
                "message": f"Unexpected error: {str(e)}",
            }

    def _normalize_payment_intent_response(self, intent) -> Dict[str, Any]:
        """Normalize PaymentIntent response to standard format."""
        status_map = {
            "succeeded": "success",
            "requires_action": "requires_action",
            "requires_payment_method": "error",
            "processing": "processing",
            "canceled": "canceled",
            "requires_capture": "requires_capture",
            "requires_confirmation": "requires_confirmation",
        }

        normalized_status = status_map.get(intent.status, intent.status)

        result = {
            "status": normalized_status,
            "provider": "stripe",
            "payment_intent_id": intent.id,
            "client_secret": intent.client_secret,
            "amount": intent.amount,
            "currency": intent.currency,
            "raw_status": intent.status,
        }

        # Add next action URL if requires action (3DS, redirects)
        if intent.status == "requires_action" and intent.next_action:
            if hasattr(intent.next_action, 'redirect_to_url') and intent.next_action.redirect_to_url:
                result["redirect_url"] = intent.next_action.redirect_to_url.url
            elif hasattr(intent.next_action, 'use_stripe_sdk'):
                result["requires_sdk_action"] = True

        # Add charge ID if available
        if intent.latest_charge:
            result["charge_id"] = intent.latest_charge

        return result


    def refund_charge(
        self,
        charge_id: Optional[str] = None,
        payment_intent_id: Optional[str] = None,
        amount: Optional[float] = None
    ) -> Dict[str, Any]:
        """Refund a Stripe charge (full or partial).
        
        Args:
            charge_id: Stripe Charge ID (ch_...)
            payment_intent_id: Stripe PaymentIntent ID (pi_...)
            amount: Amount to refund. If None, full refund.
            
        Returns:
            Dictionary with refund result
        """
        if not self._credentials_configured or not self._client:
            return {
                "status": "error",
                "provider": "stripe",
                "message": "Stripe API key not configured",
            }

        if not charge_id and not payment_intent_id:
            return {
                "status": "error",
                "provider": "stripe",
                "message": "Either charge_id or payment_intent_id is required",
            }

        try:
            refund_params = {}

            if charge_id:
                refund_params["charge"] = charge_id
            elif payment_intent_id:
                refund_params["payment_intent"] = payment_intent_id

            if amount is not None:
                refund_params["amount"] = int(amount * 100)

            refund = self._client.v1.refunds.create(refund_params)

            return {
                "status": "success",
                "provider": "stripe",
                "refund_id": refund.id,
                "amount_refunded": refund.amount,
                "currency": refund.currency,
                "refund_status": refund.status,
            }

        except StripeError as e:
            logger.error(f"Stripe API error refunding: {e}")
            return {
                "status": "error",
                "provider": "stripe",
                "message": str(e.user_message) if hasattr(e, 'user_message') else str(e),
            }
        except Exception as e:
            logger.error(f"Unexpected error refunding: {e}")
            return {
                "status": "error",
                "provider": "stripe",
                "message": f"Unexpected error: {str(e)}",
            }
        
    def capture_charge(
        self,
        payment_intent_id: str,
        amount: Optional[float] = None,
    ) -> Dict[str, Any]:
        """Capture a previously authorized PaymentIntent.
        
        Use this when create_charge was called with capture=False (manual capture).
        
        Args:
            payment_intent_id: PaymentIntent ID to capture
            amount: Amount to capture (for partial capture). If None, captures full amount.
            
        Returns:
            Dictionary with capture result
        """
        if not self._credentials_configured or not self._client:
            return {
                "status": "error",
                "provider": "stripe",
                "message": "Stripe API key not configured",
            }

        try:
            capture_params = {}
            if amount is not None:
                capture_params["amount_to_capture"] = int(amount * 100)

            intent = self._client.v1.payment_intents.capture(
                payment_intent_id,
                capture_params if capture_params else None
            )

            return self._normalize_payment_intent_response(intent)

        except StripeError as e:
            logger.error(f"Stripe API error capturing: {e}")
            return {
                "status": "error",
                "provider": "stripe",
                "message": str(e.user_message) if hasattr(e, 'user_message') else str(e),
            }
        except Exception as e:
            logger.error(f"Unexpected error capturing: {e}")
            return {
                "status": "error",
                "provider": "stripe",
                "message": f"Unexpected error: {str(e)}",
            }

    def create_checkout_session(
        self,
        success_url: str,
        cancel_url: str,
        amount: Optional[float] = None,
        currency: str = "usd",
        product_name: str = "BarZ Payment",
        metadata: Optional[Dict[str, str]] = None,
        customer_email: Optional[str] = None,
        payment_method_types: Optional[List[str]] = None,
    ) -> Dict[str, Any]:
        """Create a Stripe Checkout Session for hosted payment page.
        
        Args:
            success_url: URL to redirect after successful payment
            cancel_url: URL to redirect if customer cancels
            amount: Amount in the currency's base unit (e.g., dollars not cents)
            currency: Currency code
            product_name: Name to display for the product
            metadata: Optional metadata to attach
            customer_email: Pre-fill customer email
            payment_method_types: List of payment methods (default: ["card"])
            
        Returns:
            Dictionary with checkout session URL
        """
        if not self._credentials_configured or not self._client:
            return {
                "status": "error",
                "provider": "stripe",
                "message": "Stripe API key not configured",
            }

        try:
            amount_cents = int((amount or 29.90) * 100)
            normalized_currency = normalize_currency(currency, target="stripe")

            session_params = {
                "success_url": success_url,
                "cancel_url": cancel_url,
                "payment_method_types": payment_method_types or ["card"],
                "mode": "payment",
                "line_items": [{
                    "price_data": {
                        "currency": normalized_currency,
                        "product_data": {
                            "name": product_name,
                        },
                        "unit_amount": amount_cents,
                    },
                    "quantity": 1,
                }],
            }

            if metadata:
                session_params["metadata"] = metadata

            if customer_email:
                session_params["customer_email"] = customer_email

            session = self._client.v1.checkout.sessions.create(session_params)

            return {
                "status": "success",
                "provider": "stripe",
                "session_id": session.id,
                "checkout_url": session.url,
            }

        except StripeError as e:
            logger.error(f"Stripe API error creating checkout session: {e}")
            return {
                "status": "error",
                "provider": "stripe",
                "message": str(e.user_message) if hasattr(e, 'user_message') else str(e),
            }
        except Exception as e:
            logger.error(f"Unexpected error creating checkout session: {e}")
            return {
                "status": "error",
                "provider": "stripe",
                "message": f"Unexpected error: {str(e)}",
            }
        
    def create_setup_intent(
        self,
        customer_id: str,
        payment_method_types: Optional[List[str]] = None,
        metadata: Optional[Dict[str, str]] = None,
    ) -> Dict[str, Any]:
        """Create a SetupIntent to save a payment method for future use.
        
        Args:
            customer_id: Stripe Customer ID
            payment_method_types: List of payment method types (default: ["card"])
            metadata: Optional metadata
            
        Returns:
            Dictionary with setup intent details
        """
        if not self._credentials_configured or not self._client:
            return {
                "status": "error",
                "provider": "stripe",
                "message": "Stripe API key not configured",
            }

        try:
            setup_params = {
                "customer": customer_id,
                "payment_method_types": payment_method_types or ["card"],
            }

            if metadata:
                setup_params["metadata"] = metadata

            intent = self._client.v1.setup_intents.create(setup_params)

            return {
                "status": "success",
                "provider": "stripe",
                "setup_intent_id": intent.id,
                "client_secret": intent.client_secret,
            }

        except StripeError as e:
            logger.error(f"Stripe API error creating setup intent: {e}")
            return {
                "status": "error",
                "provider": "stripe",
                "message": str(e.user_message) if hasattr(e, 'user_message') else str(e),
            }
        except Exception as e:
            logger.error(f"Unexpected error creating setup intent: {e}")
            return {
                "status": "error",
                "provider": "stripe",
                "message": f"Unexpected error: {str(e)}",
            }

    def create_customer(
        self,
        email: str,
        name: Optional[str] = None,
        metadata: Optional[Dict[str, str]] = None,
    ) -> Dict[str, Any]:
        """Create a Stripe Customer.
        
        Args:
            email: Customer email
            name: Customer name
            metadata: Optional metadata
            
        Returns:
            Dictionary with customer ID
        """
        if not self._credentials_configured or not self._client:
            return {
                "status": "error",
                "provider": "stripe",
                "message": "Stripe API key not configured",
            }

        try:
            customer_params = {"email": email}
            if name:
                customer_params["name"] = name
            if metadata:
                customer_params["metadata"] = metadata

            customer = self._client.v1.customers.create(customer_params)

            return {
                "status": "success",
                "provider": "stripe",
                "customer_id": customer.id,
                "email": customer.email,
            }

        except StripeError as e:
            logger.error(f"Stripe API error creating customer: {e}")
            return {
                "status": "error",
                "provider": "stripe",
                "message": str(e.user_message) if hasattr(e, 'user_message') else str(e),
            }
        except Exception as e:
            logger.error(f"Unexpected error creating customer: {e}")
            return {
                "status": "error",
                "provider": "stripe",
                "message": f"Unexpected error: {str(e)}",
            }

    def get_payment_intent(self, payment_intent_id: str) -> Dict[str, Any]:
        """Retrieve a PaymentIntent by ID.
        
        Args:
            payment_intent_id: PaymentIntent ID
            
        Returns:
            Dictionary with payment intent details
        """
        if not self._credentials_configured or not self._client:
            return {
                "status": "error",
                "provider": "stripe",
                "message": "Stripe API key not configured",
            }

        try:
            intent = self._client.v1.payment_intents.retrieve(payment_intent_id)
            return self._normalize_payment_intent_response(intent)

        except StripeError as e:
            logger.error(f"Stripe API error retrieving payment intent: {e}")
            return {
                "status": "error",
                "provider": "stripe",
                "message": str(e.user_message) if hasattr(e, 'user_message') else str(e),
            }
        except Exception as e:
            logger.error(f"Unexpected error retrieving payment intent: {e}")
            return {
                "status": "error",
                "provider": "stripe",
                "message": f"Unexpected error: {str(e)}",
            }

    def create_payment_method(
        self,
        card_number: str,
        exp_month: int,
        exp_year: int,
        cvc: str,
    ) -> Dict[str, Any]:
        """Create a PaymentMethod from card details.
        
        NOTE: In production, card details should be tokenized on the frontend
        using Stripe.js or Elements. This method is primarily for testing.
        
        Args:
            card_number: Card number
            exp_month: Expiration month (1-12)
            exp_year: Expiration year (2-digit or 4-digit)
            cvc: Card CVC
            
        Returns:
            Dictionary with payment method ID
        """
        if not self._credentials_configured or not self._client:
            return {
                "status": "error",
                "provider": "stripe",
                "message": "Stripe API key not configured",
            }

        try:
            pm = self._client.v1.payment_methods.create({
                "type": "card",
                "card": {
                    "number": card_number,
                    "exp_month": exp_month,
                    "exp_year": exp_year,
                    "cvc": cvc,
                },
            })

            return {
                "status": "success",
                "provider": "stripe",
                "payment_method_id": pm.id,
                "card_brand": pm.card.brand if pm.card else None,
                "card_last4": pm.card.last4 if pm.card else None,
            }

        except StripeError as e:
            logger.error(f"Stripe API error creating payment method: {e}")
            return {
                "status": "error",
                "provider": "stripe",
                "message": str(e.user_message) if hasattr(e, 'user_message') else str(e),
            }
        except Exception as e:
            logger.error(f"Unexpected error creating payment method: {e}")
            return {
                "status": "error",
                "provider": "stripe",
                "message": f"Unexpected error: {str(e)}",
            }


