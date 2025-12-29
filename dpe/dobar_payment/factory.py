"""
dobar-payment-engine: Gateway Factory

Enterprise-grade payment gateway factory with:
- Dynamic gateway routing based on region/currency
- Health-based failover
- Circuit breaker integration
- Rate limiting
- Idempotency enforcement
- Configuration validation
"""

from typing import Dict, Any, Optional, List, Type
from functools import lru_cache
from dotenv import load_dotenv
import os
import logging
import time

from dobar_payment.interfaces import PaymentGateway, GatewayCapability
from dobar_payment.gateways.stripe import StripePaymentGateway
from dobar_payment.gateways.paypal import PaypalPaymentGateway
from dobar_payment.gateways.stone import StonePaymentGateway
from dobar_payment.middleware import (
    get_circuit_breaker,
    get_rate_limiter,
    get_idempotency_store,
    hash_params,
    PaymentContext,
    CircuitState,
)
from dobar_payment.exceptions import (
    PaymentException,
    PaymentErrorCode,
    GatewayUnavailableException,
    RateLimitedException,
    IdempotencyConflictException,
    DuplicateTransactionException,
)

load_dotenv()

logger = logging.getLogger("dobar.payment.factory")

__all__ = [
    "get_payment_gateway",
    "PaymentEngine",
    "GatewayRegistry",
]


# ============================================================================
# Gateway Registry
# ============================================================================

class GatewayRegistry:
    """
    Registry of available payment gateways.
    
    Manages gateway instances, health checks, and routing decisions.
    """
    
    # Gateway class mappings
    GATEWAY_CLASSES: Dict[str, Type[PaymentGateway]] = {
        "stripe": StripePaymentGateway,
        "stone": StonePaymentGateway,
        "paypal": PaypalPaymentGateway,
    }
    
    # Region-based gateway recommendations
    REGION_GATEWAYS: Dict[str, List[str]] = {
        "BR": ["stone", "stripe"],  # Brazil: Stone preferred
        "LATAM": ["stripe", "paypal"],  # Other LATAM: Stripe preferred
        "US": ["stripe", "paypal"],
        "EU": ["stripe", "paypal"],
        "GLOBAL": ["paypal", "stripe"],
    }
    
    # Currency to gateway mapping
    CURRENCY_GATEWAYS: Dict[str, List[str]] = {
        "BRL": ["stone", "stripe"],
        "USD": ["stripe", "paypal"],
        "EUR": ["stripe", "paypal"],
        "MXN": ["stripe"],
        "ARS": ["stripe"],
    }
    
    def __init__(self):
        self._instances: Dict[str, PaymentGateway] = {}
        self._configs: Dict[str, Dict[str, Any]] = {}
        self._load_configs()
    
    def _load_configs(self) -> None:
        """Load gateway configurations from environment."""
        # Stripe config
        self._configs["stripe"] = {
            "STRIPE_API_KEY": os.getenv("STRIPE_API_KEY"),
        }
        
        # Stone/Pagar.me config
        self._configs["stone"] = {
            "PAGARME_USERNAME": os.getenv("PAGARME_USERNAME"),
            "PAGARME_PASSWORD": os.getenv("PAGARME_PASSWORD", ""),
            "PAGARME_ENV": os.getenv("PAGARME_ENV", "production"),
        }
        
        # PayPal config
        self._configs["paypal"] = {
            "PAYPAL_CLIENT_ID": os.getenv("PAYPAL_CLIENT_ID"),
            "PAYPAL_CLIENT_SECRET": os.getenv("PAYPAL_CLIENT_SECRET"),
            "PAYPAL_ENV": os.getenv("PAYPAL_ENV", "sandbox"),
        }
    
    def get_gateway(self, name: str) -> PaymentGateway:
        """
        Get or create a gateway instance.
        
        Args:
            name: Gateway name (stripe, stone, paypal)
            
        Returns:
            PaymentGateway instance
            
        Raises:
            ValueError: If gateway not found or not configured
        """
        if name not in self.GATEWAY_CLASSES:
            raise ValueError(f"Unknown gateway: {name}. Available: {list(self.GATEWAY_CLASSES.keys())}")
        
        if name not in self._instances:
            gateway_class = self.GATEWAY_CLASSES[name]
            config = self._configs.get(name, {})
            self._instances[name] = gateway_class(config)
            logger.info(f"Created gateway instance: {name}")
        
        return self._instances[name]
    
    def get_gateway_for_currency(self, currency: str) -> Optional[PaymentGateway]:
        """Get the best available gateway for a currency."""
        gateways = self.CURRENCY_GATEWAYS.get(currency.upper(), ["stripe"])
        
        for name in gateways:
            circuit = get_circuit_breaker(name)
            if circuit.is_available():
                try:
                    gateway = self.get_gateway(name)
                    if gateway.supports_currency(currency):
                        return gateway
                except ValueError:
                    continue
        
        return None
    
    def get_gateway_for_region(self, region: str) -> Optional[PaymentGateway]:
        """Get the best available gateway for a region."""
        gateways = self.REGION_GATEWAYS.get(region.upper(), ["stripe"])
        
        for name in gateways:
            circuit = get_circuit_breaker(name)
            if circuit.is_available():
                try:
                    return self.get_gateway(name)
                except ValueError:
                    continue
        
        return None
    
    def health_check_all(self) -> Dict[str, Dict[str, Any]]:
        """Run health checks on all configured gateways."""
        results = {}
        for name in self.GATEWAY_CLASSES:
            try:
                gateway = self.get_gateway(name)
                start = time.monotonic()
                health = gateway.health_check()
                health["latency_ms"] = (time.monotonic() - start) * 1000
                results[name] = health
            except Exception as e:
                results[name] = {
                    "healthy": False,
                    "gateway": name,
                    "error": str(e),
                }
        return results
    
    def list_available(self) -> List[str]:
        """List all available (healthy) gateways."""
        available = []
        for name in self.GATEWAY_CLASSES:
            circuit = get_circuit_breaker(name)
            if circuit.is_available():
                available.append(name)
        return available


# Global registry instance
_registry = GatewayRegistry()


def get_registry() -> GatewayRegistry:
    """Get the global gateway registry."""
    return _registry


# ============================================================================
# Payment Engine (Main Entry Point)
# ============================================================================

class PaymentEngine:
    """
    Enterprise payment engine with built-in safety mechanisms.
    
    Wraps gateway operations with:
    - Idempotency checks (prevent double charges)
    - Circuit breaker (prevent cascading failures)
    - Rate limiting (prevent gateway overload)
    - Automatic retries with backoff
    - Structured logging
    
    Usage:
        engine = PaymentEngine()
        result = engine.charge(
            amount=100.00,
            currency="BRL",
            customer={...},
            payment_method={...},
            idempotency_key="unique-key-123"
        )
    """
    
    def __init__(
        self,
        gateway: Optional[str] = None,
        enable_idempotency: bool = True,
        enable_circuit_breaker: bool = True,
        enable_rate_limiting: bool = True,
        max_retries: int = 3,
    ):
        """
        Initialize the payment engine.
        
        Args:
            gateway: Specific gateway to use (or auto-select)
            enable_idempotency: Enable idempotency checks
            enable_circuit_breaker: Enable circuit breaker pattern
            enable_rate_limiting: Enable rate limiting
            max_retries: Maximum retry attempts for transient failures
        """
        self._gateway_name = gateway or os.getenv("PAYMENT_GATEWAY", "stone")
        self._enable_idempotency = enable_idempotency
        self._enable_circuit_breaker = enable_circuit_breaker
        self._enable_rate_limiting = enable_rate_limiting
        self._max_retries = max_retries
        self._registry = get_registry()
    
    @property
    def gateway(self) -> PaymentGateway:
        """Get the active gateway instance."""
        return self._registry.get_gateway(self._gateway_name)
    
    def _check_circuit_breaker(self) -> None:
        """Check if circuit breaker allows requests."""
        if not self._enable_circuit_breaker:
            return
        
        circuit = get_circuit_breaker(self._gateway_name)
        if not circuit.is_available():
            raise GatewayUnavailableException(
                message=f"Gateway {self._gateway_name} is temporarily unavailable",
                gateway=self._gateway_name,
            )
    
    def _check_rate_limit(self) -> None:
        """Check if rate limit allows requests."""
        if not self._enable_rate_limiting:
            return
        
        limiter = get_rate_limiter(self._gateway_name)
        if not limiter.acquire():
            wait_time = limiter.wait_time()
            raise RateLimitedException(
                message="Rate limit exceeded",
                retry_after=int(wait_time) + 1,
                gateway=self._gateway_name,
            )
    
    def _check_idempotency(
        self,
        idempotency_key: Optional[str],
        params_hash: str,
    ) -> Optional[Dict[str, Any]]:
        """
        Check idempotency and return cached result if available.
        
        Returns:
            Cached result if idempotency key was seen, None otherwise
            
        Raises:
            IdempotencyConflictException: If key was used with different params
        """
        if not self._enable_idempotency or not idempotency_key:
            return None
        
        store = get_idempotency_store()
        cached = store.get(idempotency_key)
        
        if cached is not None:
            # Check if params match
            stored_hash = store.get_params_hash(idempotency_key)
            if stored_hash and stored_hash != params_hash:
                raise IdempotencyConflictException(
                    message="Idempotency key was used with different parameters",
                    idempotency_key=idempotency_key,
                    gateway=self._gateway_name,
                )
            
            logger.info(f"Returning cached result for idempotency key: {idempotency_key}")
            return cached
        
        return None
    
    def _store_idempotency(
        self,
        idempotency_key: Optional[str],
        params_hash: str,
        result: Dict[str, Any],
    ) -> None:
        """Store result for idempotency key."""
        if not self._enable_idempotency or not idempotency_key:
            return
        
        # Only cache successful results
        if result.get("status") == "success":
            store = get_idempotency_store()
            store.set(idempotency_key, result, params_hash)
    
    def _record_result(self, success: bool) -> None:
        """Record result for circuit breaker."""
        if not self._enable_circuit_breaker:
            return
        
        circuit = get_circuit_breaker(self._gateway_name)
        if success:
            circuit.record_success()
        else:
            circuit.record_failure()
    
    def charge(
        self,
        amount: float,
        currency: str,
        customer: Dict[str, Any],
        payment_method: Dict[str, Any],
        idempotency_key: Optional[str] = None,
        **kwargs
    ) -> Dict[str, Any]:
        """
        Create a payment charge with enterprise safety mechanisms.
        
        Args:
            amount: Amount in currency units
            currency: ISO 4217 currency code
            customer: Customer data
            payment_method: Payment method details
            idempotency_key: Unique key to prevent duplicates
            **kwargs: Additional parameters
            
        Returns:
            Charge result dictionary
        """
        ctx = PaymentContext(
            idempotency_key=idempotency_key,
            gateway=self._gateway_name,
        )
        
        # Calculate params hash for idempotency validation
        params_hash = hash_params(amount, currency, customer, payment_method, kwargs)
        
        try:
            # 1. Check idempotency first (return cached if exists)
            cached = self._check_idempotency(idempotency_key, params_hash)
            if cached:
                cached["_cached"] = True
                return cached
            
            # 2. Check circuit breaker
            self._check_circuit_breaker()
            
            # 3. Check rate limit
            self._check_rate_limit()
            
            # 4. Execute charge
            logger.info(
                f"Creating charge: {amount} {currency}",
                extra=ctx.to_dict()
            )
            
            result = self.gateway.create_charge(
                amount=amount,
                currency=currency,
                customer=customer,
                payment_method=payment_method,
                idempotency_key=idempotency_key,
                **kwargs
            )
            
            # 5. Record result for circuit breaker
            success = result.get("status") == "success"
            self._record_result(success)
            
            # 6. Store for idempotency
            self._store_idempotency(idempotency_key, params_hash, result)
            
            # 7. Add context to result
            result["request_id"] = ctx.request_id
            result["elapsed_ms"] = ctx.elapsed_ms
            
            return result
            
        except PaymentException:
            self._record_result(False)
            raise
        except Exception as e:
            self._record_result(False)
            logger.exception(f"Unexpected error in charge: {e}")
            return {
                "status": "error",
                "provider": self._gateway_name,
                "message": str(e),
                "request_id": ctx.request_id,
            }
    
    def refund(
        self,
        charge_id: Optional[str] = None,
        payment_intent_id: Optional[str] = None,
        amount: Optional[float] = None,
        idempotency_key: Optional[str] = None,
        **kwargs
    ) -> Dict[str, Any]:
        """
        Refund a charge with enterprise safety mechanisms.
        
        Args:
            charge_id: Charge ID to refund
            payment_intent_id: Alternative ID format
            amount: Amount to refund (None = full)
            idempotency_key: Unique key to prevent duplicates
            **kwargs: Additional parameters
            
        Returns:
            Refund result dictionary
        """
        ctx = PaymentContext(
            idempotency_key=idempotency_key,
            gateway=self._gateway_name,
        )
        
        params_hash = hash_params(charge_id, payment_intent_id, amount, kwargs)
        
        try:
            cached = self._check_idempotency(idempotency_key, params_hash)
            if cached:
                cached["_cached"] = True
                return cached
            
            self._check_circuit_breaker()
            self._check_rate_limit()
            
            result = self.gateway.refund_charge(
                charge_id=charge_id,
                payment_intent_id=payment_intent_id,
                amount=amount,
                idempotency_key=idempotency_key,
                **kwargs
            )
            
            success = result.get("status") == "success"
            self._record_result(success)
            self._store_idempotency(idempotency_key, params_hash, result)
            
            result["request_id"] = ctx.request_id
            result["elapsed_ms"] = ctx.elapsed_ms
            
            return result
            
        except PaymentException:
            self._record_result(False)
            raise
        except Exception as e:
            self._record_result(False)
            return {
                "status": "error",
                "provider": self._gateway_name,
                "message": str(e),
                "request_id": ctx.request_id,
            }
    
    def capture(
        self,
        payment_intent_id: str,
        amount: Optional[float] = None,
        idempotency_key: Optional[str] = None,
        **kwargs
    ) -> Dict[str, Any]:
        """
        Capture a previously authorized charge.
        
        Args:
            payment_intent_id: Authorization ID
            amount: Amount to capture (None = full)
            idempotency_key: Unique key to prevent duplicates
            **kwargs: Additional parameters
            
        Returns:
            Capture result dictionary
        """
        ctx = PaymentContext(
            idempotency_key=idempotency_key,
            gateway=self._gateway_name,
        )
        
        params_hash = hash_params(payment_intent_id, amount, kwargs)
        
        try:
            cached = self._check_idempotency(idempotency_key, params_hash)
            if cached:
                cached["_cached"] = True
                return cached
            
            self._check_circuit_breaker()
            self._check_rate_limit()
            
            result = self.gateway.capture_charge(
                payment_intent_id=payment_intent_id,
                amount=amount,
                idempotency_key=idempotency_key,
                **kwargs
            )
            
            success = result.get("status") == "success"
            self._record_result(success)
            self._store_idempotency(idempotency_key, params_hash, result)
            
            result["request_id"] = ctx.request_id
            result["elapsed_ms"] = ctx.elapsed_ms
            
            return result
            
        except PaymentException:
            self._record_result(False)
            raise
        except Exception as e:
            self._record_result(False)
            return {
                "status": "error",
                "provider": self._gateway_name,
                "message": str(e),
                "request_id": ctx.request_id,
            }
    
    def health_check(self) -> Dict[str, Any]:
        """Check gateway health."""
        return self.gateway.health_check()


# ============================================================================
# FastAPI Dependency (Backward Compatible)
# ============================================================================

def get_payment_gateway() -> PaymentGateway:
    """
    FastAPI dependency to get the payment gateway.
    
    Backward-compatible with existing routes.
    Uses PAYMENT_GATEWAY env var to select gateway.
    
    Usage:
        @app.post("/charge")
        def charge(gateway: PaymentGateway = Depends(get_payment_gateway)):
            return gateway.create_charge(...)
    """
    gateway_name = os.getenv("PAYMENT_GATEWAY", "stone")
    logger.debug(f"Using payment gateway: {gateway_name}")
    return _registry.get_gateway(gateway_name)


def get_payment_engine() -> PaymentEngine:
    """
    FastAPI dependency to get the payment engine.
    
    Provides enterprise features (idempotency, circuit breaker, etc.)
    
    Usage:
        @app.post("/charge")
        def charge(engine: PaymentEngine = Depends(get_payment_engine)):
            return engine.charge(...)
    """
    return PaymentEngine()
