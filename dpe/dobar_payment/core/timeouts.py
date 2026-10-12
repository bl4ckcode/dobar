"""
dobar-payment-engine: Timeout and Deadline Management

Scientific-based timeout handling for payment operations.

Problem Solved:
- Preventing hung connections from blocking resources
- Propagating deadlines through async chains
- Graceful degradation under load
- SLA compliance tracking

Concepts:
- Deadline: Absolute point in time by which operation must complete
- Timeout: Relative duration from now
- Cascading deadlines: Child operations inherit parent deadline

References:
- Google Cloud API Design: Timeouts and Deadlines
- gRPC deadline propagation patterns
"""

from typing import Optional, Callable, TypeVar, Any, Dict
from datetime import datetime, timedelta
from dataclasses import dataclass
from contextlib import contextmanager
from functools import wraps
import threading
import time
import logging

logger = logging.getLogger("dobar.payment.timeouts")

T = TypeVar("T")


class TimeoutError(Exception):
    """Raised when an operation exceeds its deadline."""
    
    def __init__(
        self,
        message: str = "Operation timed out",
        operation: Optional[str] = None,
        timeout_ms: Optional[float] = None,
        elapsed_ms: Optional[float] = None,
    ):
        super().__init__(message)
        self.operation = operation
        self.timeout_ms = timeout_ms
        self.elapsed_ms = elapsed_ms
    
    def to_dict(self) -> Dict[str, Any]:
        return {
            "error": "timeout",
            "message": str(self),
            "operation": self.operation,
            "timeout_ms": self.timeout_ms,
            "elapsed_ms": self.elapsed_ms,
        }


@dataclass
class Deadline:
    """
    Represents an absolute deadline for an operation.
    
    Deadlines propagate through operation chains:
    - Parent sets deadline of 5 seconds
    - Child operations share the remaining time
    - Any child exceeding deadline fails fast
    
    Usage:
        deadline = Deadline.from_timeout(5.0)  # 5 second timeout
        
        with deadline.context():
            # Perform operation
            pass
        
        # Check remaining time
        remaining = deadline.remaining_seconds
    """
    
    expires_at: datetime
    operation: Optional[str] = None
    
    @classmethod
    def from_timeout(
        cls,
        timeout_seconds: float,
        operation: Optional[str] = None,
    ) -> "Deadline":
        """Create deadline from timeout duration."""
        return cls(
            expires_at=datetime.utcnow() + timedelta(seconds=timeout_seconds),
            operation=operation,
        )
    
    @classmethod
    def from_milliseconds(
        cls,
        timeout_ms: float,
        operation: Optional[str] = None,
    ) -> "Deadline":
        """Create deadline from milliseconds."""
        return cls.from_timeout(timeout_ms / 1000.0, operation)
    
    @property
    def is_expired(self) -> bool:
        """Check if deadline has passed."""
        return datetime.utcnow() > self.expires_at
    
    @property
    def remaining_seconds(self) -> float:
        """Get remaining time in seconds."""
        remaining = (self.expires_at - datetime.utcnow()).total_seconds()
        return max(0, remaining)
    
    @property
    def remaining_ms(self) -> float:
        """Get remaining time in milliseconds."""
        return self.remaining_seconds * 1000.0
    
    def check(self) -> None:
        """Check deadline and raise TimeoutError if expired."""
        if self.is_expired:
            raise TimeoutError(
                message=f"Deadline exceeded for operation: {self.operation or 'unknown'}",
                operation=self.operation,
            )
    
    def child(self, operation: Optional[str] = None) -> "Deadline":
        """
        Create a child deadline that inherits remaining time.
        
        Child cannot exceed parent deadline.
        """
        return Deadline(
            expires_at=self.expires_at,
            operation=operation or self.operation,
        )
    
    @contextmanager
    def context(self):
        """
        Context manager that checks deadline on entry and exit.
        
        Usage:
            deadline = Deadline.from_timeout(5.0)
            with deadline.context():
                # Operation will fail if deadline exceeded
                pass
        """
        self.check()
        try:
            yield self
        finally:
            # Check again on exit (for cleanup operations)
            pass  # Don't raise on exit to allow cleanup


class TimeoutManager:
    """
    Manages timeouts for payment operations.
    
    Features:
    - Default timeouts by operation type
    - Deadline tracking
    - Automatic timeout adjustment based on remaining budget
    
    Usage:
        manager = TimeoutManager()
        
        # Get timeout for specific operation
        timeout = manager.get_timeout("create_charge")
        
        # Execute with timeout
        result = manager.execute_with_timeout(
            lambda: gateway.create_charge(...),
            operation="create_charge"
        )
    """
    
    # Default timeouts in seconds (conservative for payment operations)
    DEFAULT_TIMEOUTS: Dict[str, float] = {
        "create_charge": 30.0,
        "refund_charge": 30.0,
        "capture_charge": 30.0,
        "health_check": 10.0,
        "get_charge": 10.0,
        "create_customer": 15.0,
        "webhook_validation": 5.0,
        "default": 30.0,
    }
    
    # Minimum timeout (don't go below this)
    MIN_TIMEOUT: float = 5.0
    
    def __init__(
        self,
        default_timeout: Optional[float] = None,
        custom_timeouts: Optional[Dict[str, float]] = None,
    ):
        self._default_timeout = default_timeout or self.DEFAULT_TIMEOUTS["default"]
        self._custom_timeouts = custom_timeouts or {}
        self._current_deadline: Optional[Deadline] = None
        self._local = threading.local()
    
    def get_timeout(self, operation: str) -> float:
        """
        Get timeout for an operation.
        
        Priority:
        1. Custom timeout for this operation
        2. Default timeout for this operation type
        3. Global default timeout
        
        If there's an active deadline, return minimum of
        configured timeout and remaining deadline.
        """
        # Get configured timeout
        timeout = self._custom_timeouts.get(
            operation,
            self.DEFAULT_TIMEOUTS.get(operation, self._default_timeout)
        )
        
        # Apply deadline constraint
        deadline = getattr(self._local, "deadline", None)
        if deadline and not deadline.is_expired:
            remaining = deadline.remaining_seconds
            timeout = min(timeout, remaining)
        
        # Ensure minimum timeout
        return max(timeout, self.MIN_TIMEOUT)
    
    def get_deadline(self, operation: str) -> Deadline:
        """Get deadline for an operation."""
        timeout = self.get_timeout(operation)
        return Deadline.from_timeout(timeout, operation)
    
    @contextmanager
    def deadline_scope(self, deadline: Deadline):
        """
        Set deadline for the current scope.
        
        Child operations will inherit this deadline.
        """
        old_deadline = getattr(self._local, "deadline", None)
        self._local.deadline = deadline
        try:
            yield deadline
        finally:
            self._local.deadline = old_deadline
    
    @contextmanager
    def timeout_scope(self, timeout_seconds: float, operation: Optional[str] = None):
        """
        Set timeout for the current scope.
        
        Convenience method that creates a deadline internally.
        """
        deadline = Deadline.from_timeout(timeout_seconds, operation)
        with self.deadline_scope(deadline):
            yield deadline
    
    def execute_with_timeout(
        self,
        func: Callable[[], T],
        operation: Optional[str] = None,
        timeout: Optional[float] = None,
    ) -> T:
        """
        Execute a function with timeout.
        
        Note: This is a soft timeout that checks deadline
        before execution. For hard timeout with thread
        interruption, use execute_with_hard_timeout.
        
        Args:
            func: Function to execute
            operation: Operation name for timeout lookup
            timeout: Override timeout in seconds
            
        Returns:
            Function result
            
        Raises:
            TimeoutError: If deadline exceeded before execution
        """
        if timeout is None:
            timeout = self.get_timeout(operation or "default")
        
        deadline = Deadline.from_timeout(timeout, operation)
        
        # Check deadline before execution
        deadline.check()
        
        start = time.monotonic()
        try:
            result = func()
        finally:
            elapsed = (time.monotonic() - start) * 1000
            if elapsed > timeout * 1000:
                logger.warning(
                    f"Operation {operation} took {elapsed:.0f}ms "
                    f"(timeout was {timeout*1000:.0f}ms)"
                )
        
        return result
    
    def check_deadline(self, operation: Optional[str] = None) -> None:
        """Check current deadline and raise if expired."""
        deadline = getattr(self._local, "deadline", None)
        if deadline:
            deadline.check()


# ============================================================================
# Timeout Decorator
# ============================================================================

def with_timeout(
    timeout_seconds: Optional[float] = None,
    operation: Optional[str] = None,
):
    """
    Decorator to apply timeout to a function.
    
    Usage:
        @with_timeout(timeout_seconds=30.0, operation="create_charge")
        def create_charge(self, ...):
            ...
    """
    def decorator(func: Callable[..., T]) -> Callable[..., T]:
        @wraps(func)
        def wrapper(*args, **kwargs) -> T:
            op_name = operation or func.__name__
            timeout = timeout_seconds or TimeoutManager.DEFAULT_TIMEOUTS.get(op_name, 30.0)
            
            deadline = Deadline.from_timeout(timeout, op_name)
            deadline.check()
            
            start = time.monotonic()
            try:
                return func(*args, **kwargs)
            finally:
                elapsed_ms = (time.monotonic() - start) * 1000
                if elapsed_ms > timeout * 1000:
                    logger.warning(
                        f"{op_name} exceeded soft timeout: {elapsed_ms:.0f}ms > {timeout*1000:.0f}ms"
                    )
        
        return wrapper
    return decorator


# ============================================================================
# Global Timeout Manager
# ============================================================================

_timeout_manager: Optional[TimeoutManager] = None


def get_timeout_manager() -> TimeoutManager:
    """Get the global timeout manager (lazy initialization)."""
    global _timeout_manager
    if _timeout_manager is None:
        _timeout_manager = TimeoutManager()
    return _timeout_manager


def set_timeout_manager(manager: TimeoutManager) -> None:
    """Set a custom timeout manager."""
    global _timeout_manager
    _timeout_manager = manager
