"""Tests for intelligent gateway router."""

import pytest

from dobar_payment.core.router import (
    GatewayRouter,
    SmartRouter,
    GatewayConfig,
    GatewayStats,
    RoutingStrategy,
)


class TestGatewayConfig:
    """Tests for GatewayConfig."""
    
    def test_supports_currency(self):
        """Test currency support check."""
        config = GatewayConfig(
            name="test",
            currencies=["BRL", "USD"],
        )
        
        assert config.supports_currency("BRL")
        assert config.supports_currency("brl")  # Case insensitive
        assert not config.supports_currency("EUR")
    
    def test_supports_currency_any(self):
        """Test any currency when currencies is None."""
        config = GatewayConfig(name="test")
        
        assert config.supports_currency("ANY")
    
    def test_supports_amount(self):
        """Test amount support check."""
        config = GatewayConfig(
            name="test",
            min_amount=10.00,
            max_amount=1000.00,
        )
        
        assert config.supports_amount(100.00)
        assert not config.supports_amount(5.00)
        assert not config.supports_amount(2000.00)


class TestGatewayStats:
    """Tests for GatewayStats."""
    
    def test_success_rate(self):
        """Test success rate calculation."""
        stats = GatewayStats(gateway="test")
        
        # No requests = 100% success assumed
        assert stats.success_rate == 1.0
        
        # Record some results
        stats.record_success(100.0)
        stats.record_success(100.0)
        stats.record_failure()
        
        assert stats.success_rate == 2/3
    
    def test_avg_latency(self):
        """Test average latency calculation."""
        stats = GatewayStats(gateway="test")
        
        stats.record_success(100.0)
        stats.record_success(200.0)
        
        assert stats.avg_latency_ms == 150.0
    
    def test_min_max_latency(self):
        """Test min/max latency tracking."""
        stats = GatewayStats(gateway="test")
        
        stats.record_success(100.0)
        stats.record_success(200.0)
        stats.record_success(50.0)
        
        assert stats.min_latency_ms == 50.0
        assert stats.max_latency_ms == 200.0


class TestGatewayRouter:
    """Tests for GatewayRouter."""
    
    def test_add_gateway(self):
        """Test adding gateways."""
        router = GatewayRouter()
        router.add_gateway(GatewayConfig(name="stripe"))
        router.add_gateway(GatewayConfig(name="stone"))
        
        assert router.select() is not None
    
    def test_select_priority(self):
        """Test priority-based selection."""
        router = GatewayRouter(default_strategy=RoutingStrategy.PRIORITY)
        router.add_gateway(GatewayConfig(name="stripe", priority=2))
        router.add_gateway(GatewayConfig(name="stone", priority=1))
        
        assert router.select() == "stone"
    
    def test_select_currency_filter(self):
        """Test filtering by currency."""
        router = GatewayRouter()
        router.add_gateway(GatewayConfig(name="stripe", currencies=["USD", "EUR"]))
        router.add_gateway(GatewayConfig(name="stone", currencies=["BRL"]))
        
        assert router.select(currency="BRL") == "stone"
        assert router.select(currency="USD") == "stripe"
    
    def test_select_amount_filter(self):
        """Test filtering by amount."""
        router = GatewayRouter()
        router.add_gateway(GatewayConfig(name="micro", max_amount=100))
        router.add_gateway(GatewayConfig(name="standard", min_amount=100))
        
        assert router.select(amount=50) == "micro"
        assert router.select(amount=500) == "standard"
    
    def test_select_exclude(self):
        """Test excluding gateways."""
        router = GatewayRouter()
        router.add_gateway(GatewayConfig(name="stripe", priority=1))
        router.add_gateway(GatewayConfig(name="stone", priority=2))
        
        result = router.select(exclude=["stripe"])
        assert result == "stone"
    
    def test_select_with_fallback(self):
        """Test selecting with fallbacks."""
        router = GatewayRouter()
        router.add_gateway(GatewayConfig(name="stripe", priority=1))
        router.add_gateway(GatewayConfig(name="stone", priority=2))
        router.add_gateway(GatewayConfig(name="paypal", priority=3))
        
        result = router.select_with_fallback(count=3)
        
        assert len(result) == 3
        assert result[0] == "stripe"
    
    def test_select_weighted(self):
        """Test weighted selection distribution."""
        router = GatewayRouter(default_strategy=RoutingStrategy.WEIGHTED)
        router.add_gateway(GatewayConfig(name="high", weight=10))
        router.add_gateway(GatewayConfig(name="low", weight=1))
        
        # Run many selections to verify distribution
        selections = {"high": 0, "low": 0}
        for _ in range(100):
            result = router.select()
            selections[result] += 1
        
        # High weight should be selected more often
        assert selections["high"] > selections["low"]
    
    def test_select_least_latency(self):
        """Test least latency selection."""
        router = GatewayRouter(default_strategy=RoutingStrategy.LEAST_LATENCY)
        router.add_gateway(GatewayConfig(name="slow"))
        router.add_gateway(GatewayConfig(name="fast"))
        
        # Record latencies
        router.record_result("slow", True, latency_ms=500)
        router.record_result("fast", True, latency_ms=100)
        
        assert router.select() == "fast"
    
    def test_select_highest_success(self):
        """Test highest success rate selection."""
        router = GatewayRouter(default_strategy=RoutingStrategy.HIGHEST_SUCCESS)
        router.add_gateway(GatewayConfig(name="reliable"))
        router.add_gateway(GatewayConfig(name="unreliable"))
        
        # Record results
        router.record_result("reliable", True)
        router.record_result("reliable", True)
        router.record_result("unreliable", True)
        router.record_result("unreliable", False)
        
        assert router.select() == "reliable"
    
    def test_select_cost_optimized(self):
        """Test cost-optimized selection."""
        router = GatewayRouter(default_strategy=RoutingStrategy.COST_OPTIMIZED)
        router.add_gateway(GatewayConfig(name="expensive", cost_percent=5.0))
        router.add_gateway(GatewayConfig(name="cheap", cost_percent=2.0))
        
        assert router.select(amount=100) == "cheap"
    
    def test_disabled_gateway_excluded(self):
        """Test that disabled gateways are excluded."""
        router = GatewayRouter()
        router.add_gateway(GatewayConfig(name="stripe", enabled=False))
        router.add_gateway(GatewayConfig(name="stone"))
        
        assert router.select() == "stone"
    
    def test_record_result(self):
        """Test recording transaction results."""
        router = GatewayRouter()
        router.add_gateway(GatewayConfig(name="test"))
        
        router.record_result("test", True, latency_ms=150)
        router.record_result("test", False)
        
        stats = router.get_stats("test")
        assert stats["total_requests"] == 2
        assert stats["successful_requests"] == 1
        assert stats["failed_requests"] == 1


class TestSmartRouter:
    """Tests for SmartRouter."""
    
    def test_default_gateways_configured(self):
        """Test that default gateways are configured."""
        router = SmartRouter()
        
        assert router.select(currency="BRL") is not None
        assert router.select(currency="USD") is not None
    
    def test_currency_preference_brl(self):
        """Test BRL currency preference."""
        router = SmartRouter()
        
        # Stone should be preferred for BRL
        assert router.select(currency="BRL") == "stone"
    
    def test_currency_preference_usd(self):
        """Test USD currency preference."""
        router = SmartRouter()
        
        # Stripe should be preferred for USD
        assert router.select(currency="USD") == "stripe"
