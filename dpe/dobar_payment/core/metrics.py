"""
dobar-payment-engine: Metrics and Observability

Scientific-based metrics collection for payment operations.

Problem Solved:
- Monitoring payment gateway performance
- Detecting degradation before failures
- Tracking success/failure rates
- Supporting intelligent gateway routing decisions

Metric Types (following Prometheus conventions):
- Counter: Monotonically increasing values (e.g., total transactions)
- Histogram: Distribution of values (e.g., latency distribution)
- Gauge: Point-in-time values (e.g., active connections)

References:
- Google SRE Book: "Site Reliability Engineering"
- Four Golden Signals: Latency, Traffic, Errors, Saturation
- RED Method: Rate, Errors, Duration
"""

from abc import ABC, abstractmethod
from typing import Dict, Any, Optional, List, Callable
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from enum import Enum
import threading
import time
import statistics
import logging

logger = logging.getLogger("dobar.payment.metrics")


# ============================================================================
# Metric Types (Abstract Interfaces)
# ============================================================================

class Counter(ABC):
    """
    Counter metric - monotonically increasing.
    
    Use for: total requests, total errors, total revenue
    """
    
    @abstractmethod
    def inc(self, value: float = 1.0, labels: Optional[Dict[str, str]] = None) -> None:
        """Increment counter by value."""
        pass
    
    @abstractmethod
    def get(self, labels: Optional[Dict[str, str]] = None) -> float:
        """Get current counter value."""
        pass


class Histogram(ABC):
    """
    Histogram metric - distribution of values.
    
    Use for: latency, request sizes, amounts
    """
    
    @abstractmethod
    def observe(self, value: float, labels: Optional[Dict[str, str]] = None) -> None:
        """Observe a value."""
        pass
    
    @abstractmethod
    def get_percentile(self, percentile: float, labels: Optional[Dict[str, str]] = None) -> float:
        """Get percentile value (0-100)."""
        pass


class Gauge(ABC):
    """
    Gauge metric - point-in-time value.
    
    Use for: active connections, queue depth, circuit breaker state
    """
    
    @abstractmethod
    def set(self, value: float, labels: Optional[Dict[str, str]] = None) -> None:
        """Set gauge value."""
        pass
    
    @abstractmethod
    def inc(self, value: float = 1.0, labels: Optional[Dict[str, str]] = None) -> None:
        """Increment gauge."""
        pass
    
    @abstractmethod
    def dec(self, value: float = 1.0, labels: Optional[Dict[str, str]] = None) -> None:
        """Decrement gauge."""
        pass
    
    @abstractmethod
    def get(self, labels: Optional[Dict[str, str]] = None) -> float:
        """Get current value."""
        pass


# ============================================================================
# In-Memory Implementations (Development/Testing)
# ============================================================================

def _labels_key(labels: Optional[Dict[str, str]]) -> str:
    """Convert labels to a hashable key."""
    if not labels:
        return ""
    return ":".join(f"{k}={v}" for k, v in sorted(labels.items()))


class InMemoryCounter(Counter):
    """Thread-safe in-memory counter."""
    
    def __init__(self, name: str, description: str = ""):
        self.name = name
        self.description = description
        self._values: Dict[str, float] = {}
        self._lock = threading.Lock()
    
    def inc(self, value: float = 1.0, labels: Optional[Dict[str, str]] = None) -> None:
        key = _labels_key(labels)
        with self._lock:
            self._values[key] = self._values.get(key, 0.0) + value
    
    def get(self, labels: Optional[Dict[str, str]] = None) -> float:
        key = _labels_key(labels)
        with self._lock:
            return self._values.get(key, 0.0)
    
    def reset(self) -> None:
        with self._lock:
            self._values.clear()


class InMemoryHistogram(Histogram):
    """Thread-safe in-memory histogram with percentile calculation."""
    
    def __init__(
        self,
        name: str,
        description: str = "",
        max_samples: int = 10000,
    ):
        self.name = name
        self.description = description
        self._max_samples = max_samples
        self._samples: Dict[str, List[float]] = {}
        self._lock = threading.Lock()
    
    def observe(self, value: float, labels: Optional[Dict[str, str]] = None) -> None:
        key = _labels_key(labels)
        with self._lock:
            if key not in self._samples:
                self._samples[key] = []
            
            samples = self._samples[key]
            samples.append(value)
            
            # Keep only recent samples
            if len(samples) > self._max_samples:
                self._samples[key] = samples[-self._max_samples:]
    
    def get_percentile(self, percentile: float, labels: Optional[Dict[str, str]] = None) -> float:
        key = _labels_key(labels)
        with self._lock:
            samples = self._samples.get(key, [])
            if not samples:
                return 0.0
            
            sorted_samples = sorted(samples)
            idx = int((percentile / 100.0) * len(sorted_samples))
            idx = min(idx, len(sorted_samples) - 1)
            return sorted_samples[idx]
    
    def get_stats(self, labels: Optional[Dict[str, str]] = None) -> Dict[str, float]:
        """Get summary statistics."""
        key = _labels_key(labels)
        with self._lock:
            samples = self._samples.get(key, [])
            if not samples:
                return {"count": 0, "min": 0, "max": 0, "mean": 0, "p50": 0, "p95": 0, "p99": 0}
            
            sorted_samples = sorted(samples)
            return {
                "count": len(samples),
                "min": min(samples),
                "max": max(samples),
                "mean": statistics.mean(samples),
                "p50": self.get_percentile(50, labels),
                "p95": self.get_percentile(95, labels),
                "p99": self.get_percentile(99, labels),
            }
    
    def reset(self) -> None:
        with self._lock:
            self._samples.clear()


class InMemoryGauge(Gauge):
    """Thread-safe in-memory gauge."""
    
    def __init__(self, name: str, description: str = ""):
        self.name = name
        self.description = description
        self._values: Dict[str, float] = {}
        self._lock = threading.Lock()
    
    def set(self, value: float, labels: Optional[Dict[str, str]] = None) -> None:
        key = _labels_key(labels)
        with self._lock:
            self._values[key] = value
    
    def inc(self, value: float = 1.0, labels: Optional[Dict[str, str]] = None) -> None:
        key = _labels_key(labels)
        with self._lock:
            self._values[key] = self._values.get(key, 0.0) + value
    
    def dec(self, value: float = 1.0, labels: Optional[Dict[str, str]] = None) -> None:
        key = _labels_key(labels)
        with self._lock:
            self._values[key] = self._values.get(key, 0.0) - value
    
    def get(self, labels: Optional[Dict[str, str]] = None) -> float:
        key = _labels_key(labels)
        with self._lock:
            return self._values.get(key, 0.0)
    
    def reset(self) -> None:
        with self._lock:
            self._values.clear()


# ============================================================================
# Metrics Provider (Abstract Factory)
# ============================================================================

class MetricsProvider(ABC):
    """
    Abstract factory for creating metrics.
    
    Implementations:
    - NullMetricsProvider: No-op for when metrics are disabled
    - InMemoryMetricsProvider: For development/testing
    - PrometheusMetricsProvider: For production (requires prometheus_client)
    """
    
    @abstractmethod
    def counter(self, name: str, description: str = "") -> Counter:
        """Create a counter metric."""
        pass
    
    @abstractmethod
    def histogram(self, name: str, description: str = "") -> Histogram:
        """Create a histogram metric."""
        pass
    
    @abstractmethod
    def gauge(self, name: str, description: str = "") -> Gauge:
        """Create a gauge metric."""
        pass


class NullCounter(Counter):
    """No-op counter."""
    def inc(self, value: float = 1.0, labels: Optional[Dict[str, str]] = None) -> None:
        pass
    def get(self, labels: Optional[Dict[str, str]] = None) -> float:
        return 0.0


class NullHistogram(Histogram):
    """No-op histogram."""
    def observe(self, value: float, labels: Optional[Dict[str, str]] = None) -> None:
        pass
    def get_percentile(self, percentile: float, labels: Optional[Dict[str, str]] = None) -> float:
        return 0.0


class NullGauge(Gauge):
    """No-op gauge."""
    def set(self, value: float, labels: Optional[Dict[str, str]] = None) -> None:
        pass
    def inc(self, value: float = 1.0, labels: Optional[Dict[str, str]] = None) -> None:
        pass
    def dec(self, value: float = 1.0, labels: Optional[Dict[str, str]] = None) -> None:
        pass
    def get(self, labels: Optional[Dict[str, str]] = None) -> float:
        return 0.0


class NullMetricsProvider(MetricsProvider):
    """No-op metrics provider (for when metrics are disabled)."""
    
    def counter(self, name: str, description: str = "") -> Counter:
        return NullCounter()
    
    def histogram(self, name: str, description: str = "") -> Histogram:
        return NullHistogram()
    
    def gauge(self, name: str, description: str = "") -> Gauge:
        return NullGauge()


class InMemoryMetricsProvider(MetricsProvider):
    """In-memory metrics provider for development and testing."""
    
    def __init__(self):
        self._counters: Dict[str, InMemoryCounter] = {}
        self._histograms: Dict[str, InMemoryHistogram] = {}
        self._gauges: Dict[str, InMemoryGauge] = {}
        self._lock = threading.Lock()
    
    def counter(self, name: str, description: str = "") -> Counter:
        with self._lock:
            if name not in self._counters:
                self._counters[name] = InMemoryCounter(name, description)
            return self._counters[name]
    
    def histogram(self, name: str, description: str = "") -> Histogram:
        with self._lock:
            if name not in self._histograms:
                self._histograms[name] = InMemoryHistogram(name, description)
            return self._histograms[name]
    
    def gauge(self, name: str, description: str = "") -> Gauge:
        with self._lock:
            if name not in self._gauges:
                self._gauges[name] = InMemoryGauge(name, description)
            return self._gauges[name]
    
    def get_all_metrics(self) -> Dict[str, Any]:
        """Get all metrics as a dictionary."""
        result = {"counters": {}, "histograms": {}, "gauges": {}}
        
        with self._lock:
            for name, counter in self._counters.items():
                result["counters"][name] = counter.get()
            
            for name, hist in self._histograms.items():
                result["histograms"][name] = hist.get_stats()
            
            for name, gauge in self._gauges.items():
                result["gauges"][name] = gauge.get()
        
        return result


# ============================================================================
# Payment-Specific Metrics
# ============================================================================

@dataclass
class PaymentMetrics:
    """
    Standard payment metrics collection.
    
    Implements the RED method:
    - Rate: requests per second
    - Errors: failed transactions
    - Duration: latency distribution
    
    Plus additional payment-specific metrics.
    """
    
    # Core metrics
    requests_total: Counter = field(default_factory=NullCounter)
    requests_success: Counter = field(default_factory=NullCounter)
    requests_failed: Counter = field(default_factory=NullCounter)
    request_duration: Histogram = field(default_factory=NullHistogram)
    
    # Gateway metrics
    gateway_health: Gauge = field(default_factory=NullGauge)
    circuit_breaker_state: Gauge = field(default_factory=NullGauge)
    rate_limiter_available: Gauge = field(default_factory=NullGauge)
    
    # Amount metrics
    amount_processed: Counter = field(default_factory=NullCounter)
    amount_refunded: Counter = field(default_factory=NullCounter)
    
    @classmethod
    def from_provider(cls, provider: MetricsProvider) -> "PaymentMetrics":
        """Create payment metrics from a provider."""
        return cls(
            requests_total=provider.counter("payment_requests_total", "Total payment requests"),
            requests_success=provider.counter("payment_requests_success", "Successful payments"),
            requests_failed=provider.counter("payment_requests_failed", "Failed payments"),
            request_duration=provider.histogram("payment_request_duration_ms", "Request duration in milliseconds"),
            gateway_health=provider.gauge("payment_gateway_health", "Gateway health status (1=healthy, 0=unhealthy)"),
            circuit_breaker_state=provider.gauge("payment_circuit_breaker_state", "Circuit breaker state (0=closed, 1=open, 2=half-open)"),
            rate_limiter_available=provider.gauge("payment_rate_limiter_available", "Rate limiter tokens available"),
            amount_processed=provider.counter("payment_amount_processed", "Total amount processed"),
            amount_refunded=provider.counter("payment_amount_refunded", "Total amount refunded"),
        )
    
    def record_request(
        self,
        gateway: str,
        method: str,
        success: bool,
        duration_ms: float,
        amount: Optional[float] = None,
    ) -> None:
        """Record a payment request."""
        labels = {"gateway": gateway, "method": method}
        
        self.requests_total.inc(labels=labels)
        
        if success:
            self.requests_success.inc(labels=labels)
            if amount:
                self.amount_processed.inc(amount, labels={"gateway": gateway})
        else:
            self.requests_failed.inc(labels=labels)
        
        self.request_duration.observe(duration_ms, labels=labels)
    
    def record_refund(self, gateway: str, amount: float) -> None:
        """Record a refund."""
        self.amount_refunded.inc(amount, labels={"gateway": gateway})


# ============================================================================
# Global Metrics Instance
# ============================================================================

_metrics_provider: Optional[MetricsProvider] = None
_payment_metrics: Optional[PaymentMetrics] = None


def get_metrics_provider() -> MetricsProvider:
    """Get the global metrics provider (lazy initialization)."""
    global _metrics_provider
    if _metrics_provider is None:
        _metrics_provider = NullMetricsProvider()
    return _metrics_provider


def set_metrics_provider(provider: MetricsProvider) -> None:
    """Set a custom metrics provider."""
    global _metrics_provider, _payment_metrics
    _metrics_provider = provider
    _payment_metrics = PaymentMetrics.from_provider(provider)


def get_payment_metrics() -> PaymentMetrics:
    """Get the global payment metrics collection."""
    global _payment_metrics
    if _payment_metrics is None:
        _payment_metrics = PaymentMetrics.from_provider(get_metrics_provider())
    return _payment_metrics


# ============================================================================
# Gateway Health Score (Intelligent Routing)
# ============================================================================

@dataclass
class GatewayHealthScore:
    """
    Composite health score for gateway routing decisions.
    
    Based on multiple factors:
    - Success rate (higher = better)
    - Latency (lower = better)
    - Error rate (lower = better)
    - Circuit breaker state
    
    Score range: 0.0 (worst) to 1.0 (best)
    """
    gateway: str
    success_rate: float  # 0.0 to 1.0
    avg_latency_ms: float
    p99_latency_ms: float
    error_rate: float  # 0.0 to 1.0
    circuit_state: int  # 0=closed, 1=open, 2=half-open
    last_updated: datetime = field(default_factory=datetime.utcnow)
    
    @property
    def composite_score(self) -> float:
        """
        Calculate composite health score.
        
        Algorithm:
        - 40% success rate
        - 30% latency score (inverse normalized)
        - 20% circuit state penalty
        - 10% consistency (low variance)
        """
        # Success component (40%)
        success_component = self.success_rate * 0.4
        
        # Latency component (30%) - normalize to 0-1, lower is better
        # Assume target latency is 200ms, penalize above 1000ms
        latency_score = max(0, 1 - (self.avg_latency_ms / 1000.0))
        latency_component = latency_score * 0.3
        
        # Circuit state penalty (20%)
        if self.circuit_state == 0:  # Closed (healthy)
            circuit_component = 0.2
        elif self.circuit_state == 2:  # Half-open (recovering)
            circuit_component = 0.1
        else:  # Open (unhealthy)
            circuit_component = 0.0
        
        # Consistency component (10%) - low variance between avg and p99
        if self.p99_latency_ms > 0:
            variance_ratio = self.avg_latency_ms / self.p99_latency_ms
            consistency_component = variance_ratio * 0.1
        else:
            consistency_component = 0.1
        
        return success_component + latency_component + circuit_component + consistency_component
    
    def to_dict(self) -> Dict[str, Any]:
        return {
            "gateway": self.gateway,
            "success_rate": self.success_rate,
            "avg_latency_ms": self.avg_latency_ms,
            "p99_latency_ms": self.p99_latency_ms,
            "error_rate": self.error_rate,
            "circuit_state": self.circuit_state,
            "composite_score": self.composite_score,
            "last_updated": self.last_updated.isoformat(),
        }
