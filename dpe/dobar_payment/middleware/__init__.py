"""
dobar-payment-engine: Middleware Layer

Enterprise-grade middleware for:
- Idempotency management (prevent double charges)
- Circuit breaker pattern (failover handling)
- Rate limiting
- Logging and metrics
- Retry logic with exponential backoff
"""

from typing import Dict, Any, Optional, Callable, TypeVar, Awaitable
from datetime import datetime, timedelta
from functools import wraps
from enum import Enum
import hashlib
import json
import time
import logging
import threading
import uuid
from collections import OrderedDict

logger = logging.getLogger("dobar.payment.middleware")

T = TypeVar("T")


# ============================================================================
# Idempotency Store (In-Memory with TTL)
# Production: Replace with Redis
# ============================================================================

class IdempotencyStore:
    """
    Thread-safe idempotency store with TTL support.
    
    Prevents duplicate transactions by caching results keyed by idempotency_key.
    In production, replace with Redis or database-backed storage.
    """
    
    def __init__(self, ttl_seconds: int = 86400, max_size: int = 10000):
        self._store: OrderedDict[str, Dict[str, Any]] = OrderedDict()
        self._lock = threading.RLock()
        self._ttl = timedelta(seconds=ttl_seconds)
        self._max_size = max_size
    
    def _cleanup_expired(self) -> None:
        """Remove expired entries."""
        now = datetime.utcnow()
        expired_keys = [
            key for key, value in self._store.items()
            if now - value["created_at"] > self._ttl
        ]
        for key in expired_keys:
            del self._store[key]
    
    def _enforce_max_size(self) -> None:
        """Remove oldest entries if over max size."""
        while len(self._store) > self._max_size:
            self._store.popitem(last=False)
    
    def get(self, key: str) -> Optional[Dict[str, Any]]:
        """Get cached result for idempotency key."""
        with self._lock:
            self._cleanup_expired()
            entry = self._store.get(key)
            if entry and datetime.utcnow() - entry["created_at"] <= self._ttl:
                return entry["result"]
            return None
    
    def set(self, key: str, result: Dict[str, Any], params_hash: str) -> None:
        """Store result for idempotency key."""
        with self._lock:
            self._store[key] = {
                "result": result,
                "params_hash": params_hash,
                "created_at": datetime.utcnow(),
            }
            self._enforce_max_size()
    
    def get_params_hash(self, key: str) -> Optional[str]:
        """Get the params hash for an existing key."""
        with self._lock:
            entry = self._store.get(key)
            if entry:
                return entry.get("params_hash")
            return None
    
    def exists(self, key: str) -> bool:
        """Check if key exists and is not expired."""
        return self.get(key) is not None


# Global idempotency store instance
_idempotency_store = IdempotencyStore()


def get_idempotency_store() -> IdempotencyStore:
    """Get the global idempotency store."""
    return _idempotency_store


# ============================================================================
# Circuit Breaker Pattern
# ============================================================================

class CircuitState(Enum):
    CLOSED = "closed"  # Normal operation
    OPEN = "open"  # Failing, reject requests
    HALF_OPEN = "half_open"  # Testing if recovered


class CircuitBreaker:
    """
    Circuit breaker pattern for gateway failover.
    
    Prevents cascading failures by temporarily blocking requests
    to a failing gateway.
    """
    
    def __init__(
        self,
        failure_threshold: int = 5,
        recovery_timeout: int = 60,
        half_open_max_calls: int = 3,
    ):
        self.failure_threshold = failure_threshold
        self.recovery_timeout = timedelta(seconds=recovery_timeout)
        self.half_open_max_calls = half_open_max_calls
        
        self._state = CircuitState.CLOSED
        self._failure_count = 0
        self._last_failure_time: Optional[datetime] = None
        self._half_open_calls = 0
        self._lock = threading.RLock()
    
    @property
    def state(self) -> CircuitState:
        with self._lock:
            if self._state == CircuitState.OPEN:
                if (
                    self._last_failure_time
                    and datetime.utcnow() - self._last_failure_time > self.recovery_timeout
                ):
                    self._state = CircuitState.HALF_OPEN
                    self._half_open_calls = 0
            return self._state
    
    def is_available(self) -> bool:
        """Check if circuit allows requests."""
        return self.state != CircuitState.OPEN
    
    def record_success(self) -> None:
        """Record a successful call."""
        with self._lock:
            if self._state == CircuitState.HALF_OPEN:
                self._half_open_calls += 1
                if self._half_open_calls >= self.half_open_max_calls:
                    self._state = CircuitState.CLOSED
                    self._failure_count = 0
                    logger.info("Circuit breaker closed - gateway recovered")
            elif self._state == CircuitState.CLOSED:
                self._failure_count = 0
    
    def record_failure(self) -> None:
        """Record a failed call."""
        with self._lock:
            self._failure_count += 1
            self._last_failure_time = datetime.utcnow()
            
            if self._state == CircuitState.HALF_OPEN:
                self._state = CircuitState.OPEN
                logger.warning("Circuit breaker opened - gateway still failing")
            elif self._failure_count >= self.failure_threshold:
                self._state = CircuitState.OPEN
                logger.warning(
                    f"Circuit breaker opened after {self._failure_count} failures"
                )


# Per-gateway circuit breakers
_circuit_breakers: Dict[str, CircuitBreaker] = {}
_circuit_lock = threading.Lock()


def get_circuit_breaker(gateway: str) -> CircuitBreaker:
    """Get or create circuit breaker for a gateway."""
    with _circuit_lock:
        if gateway not in _circuit_breakers:
            _circuit_breakers[gateway] = CircuitBreaker()
        return _circuit_breakers[gateway]


# ============================================================================
# Rate Limiter
# ============================================================================

class RateLimiter:
    """
    Token bucket rate limiter.
    
    Prevents overwhelming payment gateways with too many requests.
    """
    
    def __init__(self, requests_per_second: float = 10.0, burst: int = 20):
        self.rate = requests_per_second
        self.burst = burst
        self._tokens = float(burst)
        self._last_refill = time.monotonic()
        self._lock = threading.Lock()
    
    def acquire(self, tokens: int = 1) -> bool:
        """Try to acquire tokens. Returns True if successful."""
        with self._lock:
            now = time.monotonic()
            elapsed = now - self._last_refill
            self._tokens = min(self.burst, self._tokens + elapsed * self.rate)
            self._last_refill = now
            
            if self._tokens >= tokens:
                self._tokens -= tokens
                return True
            return False
    
    def wait_time(self, tokens: int = 1) -> float:
        """Calculate wait time to acquire tokens."""
        with self._lock:
            if self._tokens >= tokens:
                return 0.0
            needed = tokens - self._tokens
            return needed / self.rate


# Per-gateway rate limiters
_rate_limiters: Dict[str, RateLimiter] = {}
_rate_lock = threading.Lock()


def get_rate_limiter(gateway: str) -> RateLimiter:
    """Get or create rate limiter for a gateway."""
    with _rate_lock:
        if gateway not in _rate_limiters:
            _rate_limiters[gateway] = RateLimiter()
        return _rate_limiters[gateway]


# ============================================================================
# Retry Logic
# ============================================================================

def calculate_backoff(attempt: int, base_delay: float = 0.5, max_delay: float = 30.0) -> float:
    """Calculate exponential backoff with jitter."""
    import random
    delay = min(base_delay * (2 ** attempt), max_delay)
    jitter = delay * 0.1 * random.random()
    return delay + jitter


def is_retryable_error(response: Dict[str, Any]) -> bool:
    """Determine if an error response is retryable."""
    if response.get("status") != "error":
        return False
    
    retryable_codes = {
        "gateway_timeout",
        "gateway_unavailable", 
        "rate_limited",
        "service_unavailable",
    }
    
    error_code = response.get("error_code", "")
    message = response.get("message", "").lower()
    
    if error_code in retryable_codes:
        return True
    if "timeout" in message or "unavailable" in message:
        return True
    
    return False


# ============================================================================
# Parameter Hashing
# ============================================================================

def hash_params(*args, **kwargs) -> str:
    """Create a deterministic hash of function parameters."""
    def serialize(obj):
        if isinstance(obj, dict):
            return {k: serialize(v) for k, v in sorted(obj.items())}
        elif isinstance(obj, (list, tuple)):
            return [serialize(v) for v in obj]
        elif hasattr(obj, "model_dump"):
            return serialize(obj.model_dump())
        elif hasattr(obj, "__dict__"):
            return serialize(obj.__dict__)
        return obj
    
    data = {"args": serialize(args), "kwargs": serialize(kwargs)}
    json_str = json.dumps(data, sort_keys=True, default=str)
    return hashlib.sha256(json_str.encode()).hexdigest()[:16]


# ============================================================================
# Request Context
# ============================================================================

class PaymentContext:
    """
    Context object passed through the payment pipeline.
    
    Contains request metadata, timing, and tracing information.
    """
    
    def __init__(
        self,
        request_id: Optional[str] = None,
        idempotency_key: Optional[str] = None,
        gateway: Optional[str] = None,
    ):
        self.request_id = request_id or str(uuid.uuid4())
        self.idempotency_key = idempotency_key
        self.gateway = gateway
        self.start_time = time.monotonic()
        self.attempt = 0
        self.metadata: Dict[str, Any] = {}
    
    @property
    def elapsed_ms(self) -> float:
        """Elapsed time in milliseconds."""
        return (time.monotonic() - self.start_time) * 1000
    
    def to_dict(self) -> Dict[str, Any]:
        return {
            "request_id": self.request_id,
            "idempotency_key": self.idempotency_key,
            "gateway": self.gateway,
            "elapsed_ms": self.elapsed_ms,
            "attempt": self.attempt,
        }
