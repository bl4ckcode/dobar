"""
dobar-payment-engine: Intelligent Gateway Router

Scientific-based gateway routing with adaptive selection.

Problem Solved:
- Optimal gateway selection for each transaction
- Load balancing across multiple gateways
- Failover handling with circuit breakers
- Cost optimization (gateway fees vary)

Routing Algorithm:
- Multi-factor scoring: success rate, latency, cost, availability
- Weighted routing with configurable preferences
- Adaptive learning from recent transactions
- Geographic and currency affinity

References:
- Load Balancing Algorithms: Weighted Round-Robin, Least Connections
- Multi-Armed Bandit for exploration/exploitation
- Google Maglev: A Fast and Reliable Software Network Load Balancer
"""

from typing import Dict, Any, Optional, List, Callable, Tuple
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from enum import Enum
from abc import ABC, abstractmethod
import threading
import random
import math
import logging

logger = logging.getLogger("dobar.payment.router")


class RoutingStrategy(str, Enum):
    """Gateway selection strategies."""
    PRIORITY = "priority"           # Use preferred gateway, failover to others
    ROUND_ROBIN = "round_robin"     # Distribute evenly
    WEIGHTED = "weighted"           # Distribute by weights
    LEAST_LATENCY = "least_latency" # Select fastest gateway
    HIGHEST_SUCCESS = "highest_success"  # Select most reliable
    ADAPTIVE = "adaptive"           # Learn optimal routing over time
    COST_OPTIMIZED = "cost_optimized"  # Minimize transaction fees


@dataclass
class GatewayStats:
    """Statistics for a gateway."""
    gateway: str
    total_requests: int = 0
    successful_requests: int = 0
    failed_requests: int = 0
    total_latency_ms: float = 0.0
    min_latency_ms: float = float("inf")
    max_latency_ms: float = 0.0
    last_success: Optional[datetime] = None
    last_failure: Optional[datetime] = None
    circuit_state: str = "closed"  # closed, open, half_open
    
    @property
    def success_rate(self) -> float:
        """Calculate success rate (0.0 to 1.0)."""
        if self.total_requests == 0:
            return 1.0  # Assume healthy if no data
        return self.successful_requests / self.total_requests
    
    @property
    def avg_latency_ms(self) -> float:
        """Calculate average latency."""
        if self.successful_requests == 0:
            return 0.0
        return self.total_latency_ms / self.successful_requests
    
    @property
    def error_rate(self) -> float:
        """Calculate error rate (0.0 to 1.0)."""
        return 1.0 - self.success_rate
    
    def record_success(self, latency_ms: float) -> None:
        """Record a successful request."""
        self.total_requests += 1
        self.successful_requests += 1
        self.total_latency_ms += latency_ms
        self.min_latency_ms = min(self.min_latency_ms, latency_ms)
        self.max_latency_ms = max(self.max_latency_ms, latency_ms)
        self.last_success = datetime.utcnow()
    
    def record_failure(self) -> None:
        """Record a failed request."""
        self.total_requests += 1
        self.failed_requests += 1
        self.last_failure = datetime.utcnow()
    
    def to_dict(self) -> Dict[str, Any]:
        return {
            "gateway": self.gateway,
            "total_requests": self.total_requests,
            "successful_requests": self.successful_requests,
            "failed_requests": self.failed_requests,
            "success_rate": self.success_rate,
            "avg_latency_ms": self.avg_latency_ms,
            "min_latency_ms": self.min_latency_ms if self.min_latency_ms != float("inf") else 0,
            "max_latency_ms": self.max_latency_ms,
            "circuit_state": self.circuit_state,
            "last_success": self.last_success.isoformat() if self.last_success else None,
            "last_failure": self.last_failure.isoformat() if self.last_failure else None,
        }


@dataclass
class GatewayConfig:
    """Configuration for a gateway in the router."""
    name: str
    weight: float = 1.0            # For weighted routing
    priority: int = 1              # Lower = higher priority
    enabled: bool = True           # Enable/disable gateway
    cost_percent: float = 2.5      # Transaction fee percentage
    min_amount: Optional[float] = None  # Minimum transaction amount
    max_amount: Optional[float] = None  # Maximum transaction amount
    currencies: Optional[List[str]] = None  # Supported currencies
    regions: Optional[List[str]] = None     # Supported regions
    
    def supports_currency(self, currency: str) -> bool:
        if self.currencies is None:
            return True
        return currency.upper() in [c.upper() for c in self.currencies]
    
    def supports_amount(self, amount: float) -> bool:
        if self.min_amount is not None and amount < self.min_amount:
            return False
        if self.max_amount is not None and amount > self.max_amount:
            return False
        return True


class GatewayRouter:
    """
    Intelligent gateway router with multiple selection strategies.
    
    Usage:
        router = GatewayRouter()
        router.add_gateway(GatewayConfig(name="stripe", priority=1))
        router.add_gateway(GatewayConfig(name="stone", priority=2))
        
        # Get best gateway for transaction
        gateway = router.select(
            amount=100.00,
            currency="BRL",
            strategy=RoutingStrategy.ADAPTIVE,
        )
    """
    
    def __init__(
        self,
        default_strategy: RoutingStrategy = RoutingStrategy.PRIORITY,
        decay_window_hours: int = 24,
    ):
        self._gateways: Dict[str, GatewayConfig] = {}
        self._stats: Dict[str, GatewayStats] = {}
        self._default_strategy = default_strategy
        self._decay_window = timedelta(hours=decay_window_hours)
        self._lock = threading.RLock()
        self._round_robin_index = 0
    
    def add_gateway(self, config: GatewayConfig) -> "GatewayRouter":
        """Add a gateway to the router."""
        with self._lock:
            self._gateways[config.name] = config
            if config.name not in self._stats:
                self._stats[config.name] = GatewayStats(gateway=config.name)
        return self
    
    def remove_gateway(self, name: str) -> bool:
        """Remove a gateway from the router."""
        with self._lock:
            if name in self._gateways:
                del self._gateways[name]
                return True
            return False
    
    def set_gateway_enabled(self, name: str, enabled: bool) -> None:
        """Enable or disable a gateway."""
        with self._lock:
            if name in self._gateways:
                self._gateways[name].enabled = enabled
    
    def record_result(
        self,
        gateway: str,
        success: bool,
        latency_ms: float = 0.0,
    ) -> None:
        """Record transaction result for learning."""
        with self._lock:
            if gateway not in self._stats:
                self._stats[gateway] = GatewayStats(gateway=gateway)
            
            stats = self._stats[gateway]
            if success:
                stats.record_success(latency_ms)
            else:
                stats.record_failure()
    
    def get_stats(self, gateway: Optional[str] = None) -> Dict[str, Any]:
        """Get gateway statistics."""
        with self._lock:
            if gateway:
                stats = self._stats.get(gateway)
                return stats.to_dict() if stats else {}
            return {name: stats.to_dict() for name, stats in self._stats.items()}
    
    def select(
        self,
        amount: Optional[float] = None,
        currency: Optional[str] = None,
        region: Optional[str] = None,
        strategy: Optional[RoutingStrategy] = None,
        exclude: Optional[List[str]] = None,
    ) -> Optional[str]:
        """
        Select the best gateway for a transaction.
        
        Args:
            amount: Transaction amount
            currency: Currency code
            region: Geographic region
            strategy: Override routing strategy
            exclude: Gateways to exclude
            
        Returns:
            Gateway name or None if no suitable gateway found
        """
        with self._lock:
            # Get available gateways
            available = self._get_available_gateways(
                amount=amount,
                currency=currency,
                region=region,
                exclude=exclude,
            )
            
            if not available:
                return None
            
            if len(available) == 1:
                return available[0]
            
            # Apply strategy
            strat = strategy or self._default_strategy
            
            if strat == RoutingStrategy.PRIORITY:
                return self._select_by_priority(available)
            elif strat == RoutingStrategy.ROUND_ROBIN:
                return self._select_round_robin(available)
            elif strat == RoutingStrategy.WEIGHTED:
                return self._select_weighted(available)
            elif strat == RoutingStrategy.LEAST_LATENCY:
                return self._select_least_latency(available)
            elif strat == RoutingStrategy.HIGHEST_SUCCESS:
                return self._select_highest_success(available)
            elif strat == RoutingStrategy.COST_OPTIMIZED:
                return self._select_cost_optimized(available, amount or 0)
            elif strat == RoutingStrategy.ADAPTIVE:
                return self._select_adaptive(available)
            else:
                return available[0]
    
    def select_with_fallback(
        self,
        amount: Optional[float] = None,
        currency: Optional[str] = None,
        count: int = 2,
        **kwargs,
    ) -> List[str]:
        """
        Select primary gateway plus fallbacks.
        
        Returns list of gateways in order of preference.
        """
        result = []
        exclude = []
        
        for _ in range(count):
            gateway = self.select(
                amount=amount,
                currency=currency,
                exclude=exclude,
                **kwargs,
            )
            if gateway:
                result.append(gateway)
                exclude.append(gateway)
            else:
                break
        
        return result
    
    def _get_available_gateways(
        self,
        amount: Optional[float] = None,
        currency: Optional[str] = None,
        region: Optional[str] = None,
        exclude: Optional[List[str]] = None,
    ) -> List[str]:
        """Filter to gateways that can handle the transaction."""
        exclude_set = set(exclude or [])
        available = []
        
        for name, config in self._gateways.items():
            if not config.enabled:
                continue
            if name in exclude_set:
                continue
            
            # Check currency support
            if currency and not config.supports_currency(currency):
                continue
            
            # Check amount limits
            if amount is not None and not config.supports_amount(amount):
                continue
            
            # Check circuit breaker
            stats = self._stats.get(name)
            if stats and stats.circuit_state == "open":
                continue
            
            available.append(name)
        
        return available
    
    def _select_by_priority(self, gateways: List[str]) -> str:
        """Select gateway with highest priority (lowest number)."""
        return min(
            gateways,
            key=lambda g: self._gateways[g].priority,
        )
    
    def _select_round_robin(self, gateways: List[str]) -> str:
        """Distribute evenly across gateways."""
        self._round_robin_index = (self._round_robin_index + 1) % len(gateways)
        return sorted(gateways)[self._round_robin_index]
    
    def _select_weighted(self, gateways: List[str]) -> str:
        """Select based on weights (probabilistic)."""
        weights = [self._gateways[g].weight for g in gateways]
        total = sum(weights)
        
        if total == 0:
            return random.choice(gateways)
        
        r = random.uniform(0, total)
        cumulative = 0
        
        for gateway, weight in zip(gateways, weights):
            cumulative += weight
            if r <= cumulative:
                return gateway
        
        return gateways[-1]
    
    def _select_least_latency(self, gateways: List[str]) -> str:
        """Select gateway with lowest average latency."""
        return min(
            gateways,
            key=lambda g: self._stats.get(g, GatewayStats(gateway=g)).avg_latency_ms,
        )
    
    def _select_highest_success(self, gateways: List[str]) -> str:
        """Select gateway with highest success rate."""
        return max(
            gateways,
            key=lambda g: self._stats.get(g, GatewayStats(gateway=g)).success_rate,
        )
    
    def _select_cost_optimized(self, gateways: List[str], amount: float) -> str:
        """Select gateway with lowest transaction cost."""
        return min(
            gateways,
            key=lambda g: amount * (self._gateways[g].cost_percent / 100),
        )
    
    def _select_adaptive(self, gateways: List[str]) -> str:
        """
        Adaptive selection using Upper Confidence Bound (UCB1) algorithm.
        
        Balances exploitation (use best known) with exploration (try uncertain options).
        
        UCB1 = success_rate + sqrt(2 * ln(total_trials) / gateway_trials)
        """
        total_trials = sum(
            self._stats.get(g, GatewayStats(gateway=g)).total_requests
            for g in gateways
        )
        
        if total_trials == 0:
            return random.choice(gateways)
        
        def ucb_score(gateway: str) -> float:
            stats = self._stats.get(gateway, GatewayStats(gateway=gateway))
            
            if stats.total_requests == 0:
                return float("inf")  # Explore unvisited
            
            # Exploitation term (success rate)
            exploitation = stats.success_rate
            
            # Exploration term (uncertainty bonus)
            exploration = math.sqrt(2 * math.log(total_trials) / stats.total_requests)
            
            # Weight by latency (prefer faster gateways)
            latency_factor = 1.0
            if stats.avg_latency_ms > 0:
                # Normalize: 100ms = 1.0, 500ms = 0.2
                latency_factor = min(1.0, 100.0 / max(100.0, stats.avg_latency_ms))
            
            return (exploitation + exploration) * latency_factor
        
        return max(gateways, key=ucb_score)


class SmartRouter(GatewayRouter):
    """
    Advanced router with geographic and currency optimization.
    
    Pre-configured with optimal gateway selections for common scenarios.
    """
    
    # Optimal gateway by currency
    CURRENCY_PREFERENCES: Dict[str, List[str]] = {
        "BRL": ["stone", "stripe"],
        "USD": ["stripe", "paypal"],
        "EUR": ["stripe", "paypal"],
        "MXN": ["stripe"],
        "ARS": ["stripe"],
    }
    
    # Optimal gateway by region
    REGION_PREFERENCES: Dict[str, List[str]] = {
        "BR": ["stone", "stripe"],
        "LATAM": ["stripe", "paypal"],
        "US": ["stripe", "paypal"],
        "EU": ["stripe", "paypal"],
        "GLOBAL": ["paypal", "stripe"],
    }
    
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self._setup_default_gateways()
    
    def _setup_default_gateways(self) -> None:
        """Configure default gateway preferences."""
        self.add_gateway(GatewayConfig(
            name="stripe",
            weight=1.0,
            priority=1,
            cost_percent=2.9,
            currencies=["USD", "EUR", "GBP", "BRL", "MXN", "ARS"],
        ))
        
        self.add_gateway(GatewayConfig(
            name="stone",
            weight=1.0,
            priority=1,
            cost_percent=2.0,
            currencies=["BRL"],
            regions=["BR"],
        ))
        
        self.add_gateway(GatewayConfig(
            name="paypal",
            weight=0.8,
            priority=2,
            cost_percent=3.49,
            currencies=["USD", "EUR", "GBP"],
        ))
    
    def select(
        self,
        amount: Optional[float] = None,
        currency: Optional[str] = None,
        region: Optional[str] = None,
        strategy: Optional[RoutingStrategy] = None,
        **kwargs,
    ) -> Optional[str]:
        """
        Smart selection with currency/region preferences.
        """
        # Get currency-based preference
        if currency:
            prefs = self.CURRENCY_PREFERENCES.get(currency.upper(), [])
            for gw in prefs:
                if gw in self._gateways and self._gateways[gw].enabled:
                    stats = self._stats.get(gw)
                    if not stats or stats.circuit_state != "open":
                        # Check if it handles the amount
                        config = self._gateways[gw]
                        if config.supports_amount(amount or 0):
                            return gw
        
        # Fallback to parent selection
        return super().select(
            amount=amount,
            currency=currency,
            region=region,
            strategy=strategy or RoutingStrategy.ADAPTIVE,
            **kwargs,
        )


# ============================================================================
# Global Router Instance
# ============================================================================

_router: Optional[GatewayRouter] = None


def get_router() -> GatewayRouter:
    """Get the global gateway router (lazy initialization)."""
    global _router
    if _router is None:
        _router = SmartRouter()
    return _router


def set_router(router: GatewayRouter) -> None:
    """Set a custom gateway router."""
    global _router
    _router = router
