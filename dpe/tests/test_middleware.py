"""Tests for dobar_payment middleware."""
import pytest
import time
from dobar_payment.middleware import (
    CircuitBreaker,
    CircuitState,
    RateLimiter,
    IdempotencyStore,
    PaymentContext,
)


class TestCircuitBreaker:
    """Test CircuitBreaker middleware."""
    
    def test_initial_state_is_closed(self):
        cb = CircuitBreaker(failure_threshold=3, recovery_timeout=60)
        assert cb.state == CircuitState.CLOSED
    
    def test_circuit_opens_after_failures(self):
        cb = CircuitBreaker(failure_threshold=3, recovery_timeout=60)
        for _ in range(3):
            cb.record_failure()
        assert cb.state == CircuitState.OPEN
    
    def test_circuit_allows_call_when_closed(self):
        cb = CircuitBreaker(failure_threshold=3, recovery_timeout=60)
        assert cb.is_available() is True
    
    def test_circuit_blocks_call_when_open(self):
        cb = CircuitBreaker(failure_threshold=3, recovery_timeout=60)
        for _ in range(3):
            cb.record_failure()
        assert cb.is_available() is False
    
    def test_success_resets_in_closed_state(self):
        cb = CircuitBreaker(failure_threshold=3, recovery_timeout=60)
        cb.record_failure()
        cb.record_failure()
        cb.record_success()
        assert cb._failure_count == 0


class TestRateLimiter:
    """Test RateLimiter middleware."""
    
    def test_allows_requests_under_limit(self):
        rl = RateLimiter(requests_per_second=100, burst=50)
        for _ in range(5):
            assert rl.acquire() is True
    
    def test_burst_limit(self):
        rl = RateLimiter(requests_per_second=10, burst=5)
        # Should allow burst amount
        for _ in range(5):
            assert rl.acquire() is True
    
    def test_wait_time_calculation(self):
        rl = RateLimiter(requests_per_second=10, burst=1)
        rl.acquire()  # Use up the token
        wait = rl.wait_time()
        assert wait >= 0


class TestIdempotencyStore:
    """Test IdempotencyStore middleware."""
    
    def test_first_request_not_cached(self):
        store = IdempotencyStore()
        result = store.get("key1")
        assert result is None
    
    def test_set_and_get(self):
        store = IdempotencyStore()
        result = {"status": "success"}
        store.set("key1", result, "hash123")
        cached = store.get("key1")
        assert cached == result
    
    def test_exists_check(self):
        store = IdempotencyStore()
        store.set("key1", {"data": 1}, "hash123")
        assert store.exists("key1") is True
        assert store.exists("key2") is False


class TestPaymentContext:
    """Test PaymentContext."""
    
    def test_create_context(self):
        ctx = PaymentContext(
            gateway="stripe",
            idempotency_key="key123",
        )
        assert ctx.gateway == "stripe"
        assert ctx.idempotency_key == "key123"
        assert ctx.request_id is not None
    
    def test_elapsed_time(self):
        ctx = PaymentContext()
        time.sleep(0.01)
        assert ctx.elapsed_ms > 0
    
    def test_to_dict(self):
        ctx = PaymentContext(gateway="paypal")
        d = ctx.to_dict()
        assert "request_id" in d
        assert d["gateway"] == "paypal"
