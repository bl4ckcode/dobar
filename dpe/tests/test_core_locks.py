"""Tests for distributed locking module."""

import pytest
from datetime import datetime, timedelta
import threading
import time

from dobar_payment.core.locks import (
    InMemoryLockProvider,
    DistributedLock,
    TransactionLock,
    LockInfo,
)


class TestInMemoryLockProvider:
    """Tests for InMemoryLockProvider."""
    
    def test_acquire_lock(self):
        """Test acquiring a lock."""
        provider = InMemoryLockProvider()
        lock_info = provider.acquire("test-key", "owner-1", ttl_seconds=30)
        
        assert lock_info is not None
        assert lock_info.key == "test-key"
        assert lock_info.owner == "owner-1"
        assert not lock_info.is_expired
    
    def test_acquire_lock_already_held(self):
        """Test acquiring a lock that's already held by another owner."""
        provider = InMemoryLockProvider()
        provider.acquire("test-key", "owner-1", ttl_seconds=30)
        
        # Different owner cannot acquire
        result = provider.acquire("test-key", "owner-2", ttl_seconds=30)
        assert result is None
    
    def test_same_owner_can_reacquire(self):
        """Test that same owner can reacquire lock (extend)."""
        provider = InMemoryLockProvider()
        provider.acquire("test-key", "owner-1", ttl_seconds=30)
        
        # Same owner should succeed (extend)
        result = provider.acquire("test-key", "owner-1", ttl_seconds=60)
        assert result is not None
    
    def test_release_lock(self):
        """Test releasing a lock."""
        provider = InMemoryLockProvider()
        provider.acquire("test-key", "owner-1", ttl_seconds=30)
        
        assert provider.release("test-key", "owner-1") is True
        assert not provider.is_locked("test-key")
    
    def test_release_wrong_owner(self):
        """Test that wrong owner cannot release lock."""
        provider = InMemoryLockProvider()
        provider.acquire("test-key", "owner-1", ttl_seconds=30)
        
        assert provider.release("test-key", "owner-2") is False
        assert provider.is_locked("test-key")
    
    def test_extend_lock(self):
        """Test extending lock TTL."""
        provider = InMemoryLockProvider()
        provider.acquire("test-key", "owner-1", ttl_seconds=30)
        
        assert provider.extend("test-key", "owner-1", ttl_seconds=60) is True
    
    def test_extend_wrong_owner(self):
        """Test that wrong owner cannot extend lock."""
        provider = InMemoryLockProvider()
        provider.acquire("test-key", "owner-1", ttl_seconds=30)
        
        assert provider.extend("test-key", "owner-2", ttl_seconds=60) is False


class TestDistributedLock:
    """Tests for DistributedLock high-level API."""
    
    def test_context_manager(self):
        """Test using lock as context manager."""
        provider = InMemoryLockProvider()
        
        with DistributedLock(provider, "test-key") as acquired:
            assert acquired is True
            assert provider.is_locked("test-key")
        
        # Lock released after context
        assert not provider.is_locked("test-key")
    
    def test_context_manager_conflict(self):
        """Test context manager when lock already held."""
        provider = InMemoryLockProvider()
        provider.acquire("test-key", "other-owner", ttl_seconds=30)
        
        lock = DistributedLock(provider, "test-key", retry_count=1, retry_delay=0.01)
        
        with lock as acquired:
            assert acquired is False


class TestTransactionLock:
    """Tests for transaction-specific locking."""
    
    def test_with_idempotency_key(self):
        """Test lock created from idempotency key."""
        provider = InMemoryLockProvider()
        
        with TransactionLock(provider, idempotency_key="order-123") as lock:
            assert lock.acquired is True
            assert "idem:order-123" in lock.key
    
    def test_with_customer_and_amount(self):
        """Test lock created from customer and amount."""
        provider = InMemoryLockProvider()
        
        with TransactionLock(provider, customer_id="cust_123", amount=100.00) as lock:
            assert lock.acquired is True
            assert lock.key.startswith("txn:")
    
    def test_concurrent_same_transaction(self):
        """Test that concurrent identical transactions are blocked."""
        provider = InMemoryLockProvider()
        
        with TransactionLock(provider, idempotency_key="order-123") as lock1:
            assert lock1.acquired is True
            
            with TransactionLock(provider, idempotency_key="order-123") as lock2:
                # Second lock should fail
                assert lock2.acquired is False


class TestLockInfo:
    """Tests for LockInfo dataclass."""
    
    def test_is_expired(self):
        """Test expiration detection."""
        # Not expired
        lock_info = LockInfo(
            key="test",
            owner="owner",
            acquired_at=datetime.utcnow(),
            expires_at=datetime.utcnow() + timedelta(seconds=30),
        )
        assert not lock_info.is_expired
        
        # Expired
        lock_info_expired = LockInfo(
            key="test",
            owner="owner",
            acquired_at=datetime.utcnow() - timedelta(seconds=60),
            expires_at=datetime.utcnow() - timedelta(seconds=30),
        )
        assert lock_info_expired.is_expired
    
    def test_remaining_ttl(self):
        """Test remaining TTL calculation."""
        lock_info = LockInfo(
            key="test",
            owner="owner",
            acquired_at=datetime.utcnow(),
            expires_at=datetime.utcnow() + timedelta(seconds=30),
        )
        assert 29 <= lock_info.remaining_ttl_seconds <= 30
