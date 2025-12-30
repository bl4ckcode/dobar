"""
dobar-payment-engine: Distributed Locking

Scientific-based distributed locking for payment transactions.

Problem Solved:
- Race conditions in concurrent payment requests
- Double-charging when same order is submitted twice
- Ensuring exactly-once semantics for financial transactions

Algorithm: Pessimistic Locking with TTL
- Lock acquired before transaction processing
- Automatic expiration prevents deadlocks
- Supports both in-memory (development) and distributed (Redis) backends

References:
- Kleppmann, M. (2016). "Designing Data-Intensive Applications"
- Redlock algorithm by Salvatore Sanfilippo
"""

from abc import ABC, abstractmethod
from typing import Optional, Dict, Any
from datetime import datetime, timedelta
from contextlib import contextmanager
from dataclasses import dataclass
import threading
import hashlib
import time
import uuid
import logging

logger = logging.getLogger("dobar.payment.locks")


@dataclass
class LockInfo:
    """Information about an acquired lock."""
    key: str
    owner: str
    acquired_at: datetime
    expires_at: datetime
    
    @property
    def is_expired(self) -> bool:
        return datetime.utcnow() > self.expires_at
    
    @property
    def remaining_ttl_seconds(self) -> float:
        remaining = (self.expires_at - datetime.utcnow()).total_seconds()
        return max(0, remaining)


class LockProvider(ABC):
    """
    Abstract interface for distributed lock providers.
    
    Implementations:
    - InMemoryLockProvider: For development/testing
    - RedisLockProvider: For production (requires redis client)
    """
    
    @abstractmethod
    def acquire(
        self,
        key: str,
        owner: str,
        ttl_seconds: int = 30,
    ) -> Optional[LockInfo]:
        """
        Try to acquire a lock.
        
        Args:
            key: Unique lock identifier
            owner: Owner identifier (usually a request ID)
            ttl_seconds: Lock expiration time
            
        Returns:
            LockInfo if acquired, None if lock already held
        """
        pass
    
    @abstractmethod
    def release(self, key: str, owner: str) -> bool:
        """
        Release a lock.
        
        Only the owner can release the lock.
        
        Args:
            key: Lock key
            owner: Owner who acquired the lock
            
        Returns:
            True if released, False if not owner or not found
        """
        pass
    
    @abstractmethod
    def extend(self, key: str, owner: str, ttl_seconds: int) -> bool:
        """
        Extend lock TTL.
        
        Args:
            key: Lock key
            owner: Owner who holds the lock
            ttl_seconds: New TTL in seconds
            
        Returns:
            True if extended, False if not owner or not found
        """
        pass
    
    @abstractmethod
    def is_locked(self, key: str) -> bool:
        """Check if a key is currently locked."""
        pass


class InMemoryLockProvider(LockProvider):
    """
    Thread-safe in-memory lock provider.
    
    Suitable for single-instance deployments and testing.
    For distributed deployments, use RedisLockProvider.
    """
    
    def __init__(self):
        self._locks: Dict[str, LockInfo] = {}
        self._lock = threading.RLock()
    
    def _cleanup_expired(self) -> None:
        """Remove expired locks."""
        now = datetime.utcnow()
        expired = [k for k, v in self._locks.items() if v.is_expired]
        for key in expired:
            del self._locks[key]
    
    def acquire(
        self,
        key: str,
        owner: str,
        ttl_seconds: int = 30,
    ) -> Optional[LockInfo]:
        with self._lock:
            self._cleanup_expired()
            
            existing = self._locks.get(key)
            if existing and not existing.is_expired:
                # Lock already held by someone else
                if existing.owner != owner:
                    logger.debug(f"Lock {key} already held by {existing.owner}")
                    return None
                # Same owner - extend lock
                return self.extend(key, owner, ttl_seconds) and existing
            
            # Acquire new lock
            now = datetime.utcnow()
            lock_info = LockInfo(
                key=key,
                owner=owner,
                acquired_at=now,
                expires_at=now + timedelta(seconds=ttl_seconds),
            )
            self._locks[key] = lock_info
            logger.debug(f"Lock acquired: {key} by {owner}")
            return lock_info
    
    def release(self, key: str, owner: str) -> bool:
        with self._lock:
            existing = self._locks.get(key)
            if not existing:
                return False
            
            if existing.owner != owner:
                logger.warning(f"Cannot release lock {key}: owner mismatch")
                return False
            
            del self._locks[key]
            logger.debug(f"Lock released: {key}")
            return True
    
    def extend(self, key: str, owner: str, ttl_seconds: int) -> bool:
        with self._lock:
            existing = self._locks.get(key)
            if not existing or existing.owner != owner:
                return False
            
            self._locks[key] = LockInfo(
                key=key,
                owner=owner,
                acquired_at=existing.acquired_at,
                expires_at=datetime.utcnow() + timedelta(seconds=ttl_seconds),
            )
            return True
    
    def is_locked(self, key: str) -> bool:
        with self._lock:
            self._cleanup_expired()
            return key in self._locks


class DistributedLock:
    """
    High-level distributed lock abstraction.
    
    Provides context manager interface for safe lock handling.
    
    Usage:
        lock_provider = InMemoryLockProvider()
        
        with DistributedLock(lock_provider, "order-123") as acquired:
            if acquired:
                # Process payment
                pass
            else:
                # Handle concurrent request
                pass
    """
    
    def __init__(
        self,
        provider: LockProvider,
        key: str,
        owner: Optional[str] = None,
        ttl_seconds: int = 30,
        retry_count: int = 3,
        retry_delay: float = 0.1,
    ):
        self._provider = provider
        self._key = key
        self._owner = owner or str(uuid.uuid4())
        self._ttl_seconds = ttl_seconds
        self._retry_count = retry_count
        self._retry_delay = retry_delay
        self._lock_info: Optional[LockInfo] = None
    
    def acquire(self) -> bool:
        """Try to acquire the lock with retries."""
        for attempt in range(self._retry_count):
            self._lock_info = self._provider.acquire(
                self._key,
                self._owner,
                self._ttl_seconds,
            )
            if self._lock_info:
                return True
            
            if attempt < self._retry_count - 1:
                time.sleep(self._retry_delay * (2 ** attempt))
        
        return False
    
    def release(self) -> bool:
        """Release the lock."""
        if self._lock_info:
            result = self._provider.release(self._key, self._owner)
            self._lock_info = None
            return result
        return False
    
    def extend(self, ttl_seconds: Optional[int] = None) -> bool:
        """Extend the lock TTL."""
        return self._provider.extend(
            self._key,
            self._owner,
            ttl_seconds or self._ttl_seconds,
        )
    
    @property
    def is_acquired(self) -> bool:
        """Check if lock is currently acquired."""
        return self._lock_info is not None and not self._lock_info.is_expired
    
    def __enter__(self) -> bool:
        return self.acquire()
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        self.release()
        return False


class TransactionLock:
    """
    Specialized lock for payment transactions.
    
    Creates a composite lock key from transaction parameters
    to prevent duplicate processing of the same transaction.
    
    Usage:
        with TransactionLock(provider, customer_id="cust_123", amount=100) as lock:
            if lock.acquired:
                process_payment()
            else:
                raise DuplicateTransactionException()
    """
    
    def __init__(
        self,
        provider: LockProvider,
        customer_id: Optional[str] = None,
        idempotency_key: Optional[str] = None,
        amount: Optional[float] = None,
        ttl_seconds: int = 60,
    ):
        self._provider = provider
        self._ttl_seconds = ttl_seconds
        
        # Build lock key from components
        self._key = self._build_key(customer_id, idempotency_key, amount)
        self._owner = str(uuid.uuid4())
        self._acquired = False
    
    def _build_key(
        self,
        customer_id: Optional[str],
        idempotency_key: Optional[str],
        amount: Optional[float],
    ) -> str:
        """Build a unique lock key from transaction parameters."""
        if idempotency_key:
            # Idempotency key is most specific
            return f"txn:idem:{idempotency_key}"
        
        # Fallback to customer + amount hash
        components = []
        if customer_id:
            components.append(f"cust:{customer_id}")
        if amount is not None:
            components.append(f"amt:{amount:.2f}")
        
        if not components:
            # No specific components - generate unique key
            return f"txn:{uuid.uuid4()}"
        
        key_str = ":".join(components)
        key_hash = hashlib.sha256(key_str.encode()).hexdigest()[:16]
        return f"txn:{key_hash}"
    
    @property
    def acquired(self) -> bool:
        return self._acquired
    
    @property
    def key(self) -> str:
        return self._key
    
    def __enter__(self) -> "TransactionLock":
        lock_info = self._provider.acquire(
            self._key,
            self._owner,
            self._ttl_seconds,
        )
        self._acquired = lock_info is not None
        
        if self._acquired:
            logger.info(f"Transaction lock acquired: {self._key}")
        else:
            logger.warning(f"Transaction lock denied: {self._key}")
        
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        if self._acquired:
            self._provider.release(self._key, self._owner)
            logger.debug(f"Transaction lock released: {self._key}")
        return False


# Global lock provider instance
_lock_provider: Optional[LockProvider] = None


def get_lock_provider() -> LockProvider:
    """Get the global lock provider (lazy initialization)."""
    global _lock_provider
    if _lock_provider is None:
        _lock_provider = InMemoryLockProvider()
    return _lock_provider


def set_lock_provider(provider: LockProvider) -> None:
    """Set a custom lock provider (e.g., Redis for production)."""
    global _lock_provider
    _lock_provider = provider
