"""
dobar-payment-engine: Gateway Interfaces

Abstract base classes defining the contract for all payment gateways.
Supports:
- Charges (one-time payments)
- Refunds (full and partial)
- Captures (for auth-only flows)
- Health checks
- Gateway capabilities discovery
"""

from abc import ABC, abstractmethod
from typing import Dict, Any, Optional, Set
from enum import Enum
import logging

logger = logging.getLogger("dobar.payment.gateway")


class GatewayCapability(str, Enum):
    """Capabilities that a gateway may support."""
    CREDIT_CARD = "credit_card"
    DEBIT_CARD = "debit_card"
    PIX = "pix"
    BOLETO = "boleto"
    PAYPAL = "paypal"
    APPLE_PAY = "apple_pay"
    GOOGLE_PAY = "google_pay"
    AUTH_ONLY = "auth_only"  # Separate auth and capture
    PARTIAL_CAPTURE = "partial_capture"
    PARTIAL_REFUND = "partial_refund"
    INSTALLMENTS = "installments"
    SAVED_CARDS = "saved_cards"
    WEBHOOKS = "webhooks"
    THREE_D_SECURE = "3ds"
    RECURRING = "recurring"


class PaymentGateway(ABC):
    """
    Abstract base class for all payment gateways.
    
    Defines the contract that all gateway implementations must follow.
    Each gateway handles its own provider-specific logic internally.
    """
    
    # Gateway identifier (e.g., "stripe", "stone", "paypal")
    GATEWAY_NAME: str = "unknown"
    
    # Supported currencies (ISO 4217)
    SUPPORTED_CURRENCIES: Set[str] = {"USD", "BRL", "EUR"}
    
    # Gateway capabilities
    CAPABILITIES: Set[GatewayCapability] = set()
    
    def __init__(self, config: Dict[str, Any]):
        """
        Initialize the gateway with configuration.
        
        Args:
            config: Gateway-specific configuration including credentials
        """
        self._config = config
        self._healthy = True
    
    # =========================================================================
    # Core Operations
    # =========================================================================
    
    @abstractmethod
    def create_charge(
        self,
        amount: float,
        currency: str,
        customer: Optional[Dict[str, Any]] = None,
        payment_method: Optional[Dict[str, Any]] = None,
        idempotency_key: Optional[str] = None,
        **kwargs
    ) -> Dict[str, Any]:
        """
        Create a payment charge.
        
        Args:
            amount: Amount in currency units (e.g., 100.50 for $100.50)
            currency: ISO 4217 currency code
            customer: Customer information (name, email, document, address)
            payment_method: Payment details (card, pix, etc.)
            idempotency_key: Unique key to prevent duplicate charges
            **kwargs: Additional gateway-specific parameters
            
        Returns:
            Dict containing:
                - status: "success" or "error"
                - charge_id: Gateway's charge/transaction ID
                - charge_status: Transaction status (pending, paid, failed, etc.)
                - provider: Gateway name
                - For PIX: qr_code, qr_code_url, pix_copia_e_cola
                - For errors: message, error_code
        """
        pass

    @abstractmethod
    def refund_charge(
        self,
        charge_id: Optional[str] = None,
        payment_intent_id: Optional[str] = None,
        amount: Optional[float] = None,
        idempotency_key: Optional[str] = None,
        **kwargs
    ) -> Dict[str, Any]:
        """
        Refund a charge, fully or partially.
        
        Args:
            charge_id: The charge ID to refund
            payment_intent_id: Alternative ID format (for Stripe)
            amount: Amount to refund (None = full refund)
            idempotency_key: Unique key to prevent duplicate refunds
            **kwargs: Additional gateway-specific parameters
            
        Returns:
            Dict containing:
                - status: "success" or "error"
                - refund_id: Gateway's refund ID
                - amount_refunded: Amount that was refunded
                - provider: Gateway name
        """
        pass

    def capture_charge(
        self,
        payment_intent_id: str,
        amount: Optional[float] = None,
        idempotency_key: Optional[str] = None,
        **kwargs
    ) -> Dict[str, Any]:
        """
        Capture a previously authorized charge.
        
        Default implementation returns error for gateways that don't support
        separate auth/capture flow.
        
        Args:
            payment_intent_id: The authorization/payment intent ID
            amount: Amount to capture (None = full amount)
            idempotency_key: Unique key to prevent duplicate captures
            **kwargs: Additional gateway-specific parameters
            
        Returns:
            Dict containing:
                - status: "success" or "error"
                - charge_id: Captured charge ID
                - amount_captured: Amount that was captured
                - provider: Gateway name
        """
        return {
            "status": "error",
            "provider": self.GATEWAY_NAME,
            "message": f"Capture not supported by {self.GATEWAY_NAME}",
        }
    
    # =========================================================================
    # Optional Operations (Override as needed)
    # =========================================================================
    
    def get_charge(self, charge_id: str, **kwargs) -> Dict[str, Any]:
        """
        Retrieve charge details.
        
        Args:
            charge_id: The charge ID to retrieve
            
        Returns:
            Dict with charge details
        """
        return {
            "status": "error",
            "provider": self.GATEWAY_NAME,
            "message": f"Get charge not implemented for {self.GATEWAY_NAME}",
        }
    
    def create_customer(self, customer: Dict[str, Any], **kwargs) -> Dict[str, Any]:
        """
        Create a customer record in the gateway.
        
        Args:
            customer: Customer data
            
        Returns:
            Dict with customer ID and details
        """
        return {
            "status": "error",
            "provider": self.GATEWAY_NAME,
            "message": f"Create customer not implemented for {self.GATEWAY_NAME}",
        }
    
    def create_setup_intent(self, customer_id: str, **kwargs) -> Dict[str, Any]:
        """
        Create a setup intent for saving payment methods.
        
        Args:
            customer_id: The customer ID to attach the payment method to
            
        Returns:
            Dict with setup intent details
        """
        return {
            "status": "error",
            "provider": self.GATEWAY_NAME,
            "message": f"Setup intent not supported by {self.GATEWAY_NAME}",
        }
    
    def create_checkout_session(
        self,
        success_url: str,
        cancel_url: str,
        **kwargs
    ) -> Dict[str, Any]:
        """
        Create a hosted checkout session.
        
        Args:
            success_url: Redirect URL on success
            cancel_url: Redirect URL on cancel
            
        Returns:
            Dict with checkout session URL
        """
        return {
            "status": "error",
            "provider": self.GATEWAY_NAME,
            "message": f"Checkout sessions not supported by {self.GATEWAY_NAME}",
        }
    
    # =========================================================================
    # Health & Capabilities
    # =========================================================================
    
    def health_check(self) -> Dict[str, Any]:
        """
        Check if the gateway is healthy and accessible.
        
        Returns:
            Dict containing:
                - healthy: bool
                - gateway: Gateway name
                - latency_ms: Response time in milliseconds
                - error: Error message if unhealthy
        """
        return {
            "healthy": self._healthy,
            "gateway": self.GATEWAY_NAME,
        }
    
    def supports(self, capability: GatewayCapability) -> bool:
        """Check if gateway supports a capability."""
        return capability in self.CAPABILITIES
    
    def supports_currency(self, currency: str) -> bool:
        """Check if gateway supports a currency."""
        return currency.upper() in self.SUPPORTED_CURRENCIES
    
    @property
    def is_configured(self) -> bool:
        """Check if gateway has valid configuration."""
        return True  # Override in subclasses
    
    # =========================================================================
    # Internal Helpers
    # =========================================================================
    
    def _log_operation(
        self,
        operation: str,
        success: bool,
        details: Optional[Dict[str, Any]] = None
    ) -> None:
        """Log an operation for debugging and monitoring."""
        log_data = {
            "gateway": self.GATEWAY_NAME,
            "operation": operation,
            "success": success,
            **(details or {}),
        }
        if success:
            logger.info(f"{operation} completed", extra=log_data)
        else:
            logger.error(f"{operation} failed", extra=log_data)
