"""
dobar-payment-engine: Transaction State Machine

Scientific-based state machine for payment transaction lifecycle.

Problem Solved:
- Tracking transaction state transitions
- Ensuring valid state transitions only
- Providing audit trail for compliance
- Enabling retry/recovery logic

State Machine Theory:
- Based on Finite State Machine (FSM) theory
- Deterministic transitions with guard conditions
- Event-driven architecture for flexibility

Transaction Lifecycle:
    CREATED → PROCESSING → AUTHORIZED → CAPTURED → SETTLED
                 ↓              ↓            ↓
              FAILED        VOIDED      REFUNDED (partial or full)
                                             ↓
                                         DISPUTED

References:
- Hopcroft, J. E., Motwani, R., & Ullman, J. D. "Introduction to Automata Theory"
- PCI DSS requirements for transaction state tracking
"""

from enum import Enum
from typing import Dict, Set, Optional, Callable, Any, List
from dataclasses import dataclass, field
from datetime import datetime
import logging
import threading

logger = logging.getLogger("dobar.payment.state_machine")


class TransactionState(str, Enum):
    """
    Payment transaction states.
    
    Lifecycle stages following industry standards and
    PCI DSS compliance requirements.
    """
    # Initial states
    CREATED = "created"           # Transaction created, not yet processed
    PENDING = "pending"           # Awaiting external action (e.g., PIX payment)
    
    # Processing states
    PROCESSING = "processing"     # Currently being processed
    AUTHORIZED = "authorized"     # Authorization approved, not captured
    
    # Success states
    CAPTURED = "captured"         # Payment captured/charged
    SETTLED = "settled"           # Funds settled to merchant
    
    # Refund states
    PARTIALLY_REFUNDED = "partially_refunded"  # Some amount refunded
    REFUNDED = "refunded"         # Fully refunded
    
    # Failure states
    FAILED = "failed"             # Processing failed
    DECLINED = "declined"         # Authorization declined
    VOIDED = "voided"             # Authorization voided before capture
    EXPIRED = "expired"           # Transaction expired (e.g., PIX timeout)
    
    # Dispute states
    DISPUTED = "disputed"         # Chargeback initiated
    DISPUTE_WON = "dispute_won"   # Merchant won dispute
    DISPUTE_LOST = "dispute_lost" # Merchant lost dispute
    
    # Terminal states
    CANCELLED = "cancelled"       # Transaction cancelled


class TransactionEvent(str, Enum):
    """
    Events that trigger state transitions.
    
    Following event-driven architecture patterns.
    """
    # Creation events
    CREATE = "create"
    SUBMIT = "submit"
    
    # Processing events
    AUTHORIZE = "authorize"
    CAPTURE = "capture"
    SETTLE = "settle"
    
    # Failure events
    FAIL = "fail"
    DECLINE = "decline"
    TIMEOUT = "timeout"
    EXPIRE = "expire"
    
    # Reversal events
    VOID = "void"
    REFUND = "refund"
    PARTIAL_REFUND = "partial_refund"
    CANCEL = "cancel"
    
    # Dispute events
    DISPUTE = "dispute"
    RESOLVE_DISPUTE_WON = "resolve_dispute_won"
    RESOLVE_DISPUTE_LOST = "resolve_dispute_lost"
    
    # Recovery events
    RETRY = "retry"


@dataclass
class StateTransition:
    """Record of a state transition for audit trail."""
    from_state: TransactionState
    to_state: TransactionState
    event: TransactionEvent
    timestamp: datetime
    actor: Optional[str] = None  # Who/what triggered the transition
    metadata: Dict[str, Any] = field(default_factory=dict)
    
    def to_dict(self) -> Dict[str, Any]:
        return {
            "from_state": self.from_state.value,
            "to_state": self.to_state.value,
            "event": self.event.value,
            "timestamp": self.timestamp.isoformat(),
            "actor": self.actor,
            "metadata": self.metadata,
        }


# Type alias for transition guard functions
TransitionGuard = Callable[[Dict[str, Any]], bool]


@dataclass
class TransitionRule:
    """
    Rule defining a valid state transition.
    
    Optionally includes a guard condition that must be satisfied.
    """
    from_state: TransactionState
    event: TransactionEvent
    to_state: TransactionState
    guard: Optional[TransitionGuard] = None
    
    def is_allowed(self, context: Optional[Dict[str, Any]] = None) -> bool:
        """Check if transition is allowed based on guard condition."""
        if self.guard is None:
            return True
        return self.guard(context or {})


class TransactionStateMachine:
    """
    Finite State Machine for payment transactions.
    
    Ensures valid state transitions and maintains audit history.
    
    Usage:
        machine = TransactionStateMachine(transaction_id="txn_123")
        
        # Process events
        machine.process_event(TransactionEvent.SUBMIT)
        machine.process_event(TransactionEvent.AUTHORIZE)
        machine.process_event(TransactionEvent.CAPTURE)
        
        # Check state
        assert machine.state == TransactionState.CAPTURED
        
        # Get history
        history = machine.get_history()
    """
    
    # Define valid state transitions
    TRANSITION_RULES: List[TransitionRule] = [
        # Creation flow
        TransitionRule(TransactionState.CREATED, TransactionEvent.SUBMIT, TransactionState.PROCESSING),
        TransitionRule(TransactionState.CREATED, TransactionEvent.CANCEL, TransactionState.CANCELLED),
        
        # Processing outcomes
        TransitionRule(TransactionState.PROCESSING, TransactionEvent.AUTHORIZE, TransactionState.AUTHORIZED),
        TransitionRule(TransactionState.PROCESSING, TransactionEvent.CAPTURE, TransactionState.CAPTURED),  # Direct capture
        TransitionRule(TransactionState.PROCESSING, TransactionEvent.FAIL, TransactionState.FAILED),
        TransitionRule(TransactionState.PROCESSING, TransactionEvent.DECLINE, TransactionState.DECLINED),
        TransitionRule(TransactionState.PROCESSING, TransactionEvent.TIMEOUT, TransactionState.PENDING),
        
        # Pending outcomes (e.g., PIX, Boleto)
        TransitionRule(TransactionState.PENDING, TransactionEvent.CAPTURE, TransactionState.CAPTURED),
        TransitionRule(TransactionState.PENDING, TransactionEvent.EXPIRE, TransactionState.EXPIRED),
        TransitionRule(TransactionState.PENDING, TransactionEvent.CANCEL, TransactionState.CANCELLED),
        
        # Authorization flow
        TransitionRule(TransactionState.AUTHORIZED, TransactionEvent.CAPTURE, TransactionState.CAPTURED),
        TransitionRule(TransactionState.AUTHORIZED, TransactionEvent.VOID, TransactionState.VOIDED),
        TransitionRule(TransactionState.AUTHORIZED, TransactionEvent.EXPIRE, TransactionState.EXPIRED),
        
        # Capture to settlement
        TransitionRule(TransactionState.CAPTURED, TransactionEvent.SETTLE, TransactionState.SETTLED),
        TransitionRule(TransactionState.CAPTURED, TransactionEvent.REFUND, TransactionState.REFUNDED),
        TransitionRule(TransactionState.CAPTURED, TransactionEvent.PARTIAL_REFUND, TransactionState.PARTIALLY_REFUNDED),
        TransitionRule(TransactionState.CAPTURED, TransactionEvent.DISPUTE, TransactionState.DISPUTED),
        
        # Settlement
        TransitionRule(TransactionState.SETTLED, TransactionEvent.REFUND, TransactionState.REFUNDED),
        TransitionRule(TransactionState.SETTLED, TransactionEvent.PARTIAL_REFUND, TransactionState.PARTIALLY_REFUNDED),
        TransitionRule(TransactionState.SETTLED, TransactionEvent.DISPUTE, TransactionState.DISPUTED),
        
        # Partial refund continuation
        TransitionRule(TransactionState.PARTIALLY_REFUNDED, TransactionEvent.REFUND, TransactionState.REFUNDED),
        TransitionRule(TransactionState.PARTIALLY_REFUNDED, TransactionEvent.PARTIAL_REFUND, TransactionState.PARTIALLY_REFUNDED),
        TransitionRule(TransactionState.PARTIALLY_REFUNDED, TransactionEvent.DISPUTE, TransactionState.DISPUTED),
        
        # Dispute resolution
        TransitionRule(TransactionState.DISPUTED, TransactionEvent.RESOLVE_DISPUTE_WON, TransactionState.DISPUTE_WON),
        TransitionRule(TransactionState.DISPUTED, TransactionEvent.RESOLVE_DISPUTE_LOST, TransactionState.DISPUTE_LOST),
        
        # Recovery (retry failed transactions)
        TransitionRule(TransactionState.FAILED, TransactionEvent.RETRY, TransactionState.PROCESSING),
        TransitionRule(TransactionState.DECLINED, TransactionEvent.RETRY, TransactionState.PROCESSING),
    ]
    
    # Terminal states (no further transitions possible)
    TERMINAL_STATES: Set[TransactionState] = {
        TransactionState.REFUNDED,
        TransactionState.VOIDED,
        TransactionState.EXPIRED,
        TransactionState.CANCELLED,
        TransactionState.DISPUTE_WON,
        TransactionState.DISPUTE_LOST,
    }
    
    def __init__(
        self,
        transaction_id: str,
        initial_state: TransactionState = TransactionState.CREATED,
    ):
        self._transaction_id = transaction_id
        self._state = initial_state
        self._history: List[StateTransition] = []
        self._lock = threading.RLock()
        
        # Build lookup table for faster transitions
        self._transitions: Dict[tuple, TransitionRule] = {}
        for rule in self.TRANSITION_RULES:
            key = (rule.from_state, rule.event)
            self._transitions[key] = rule
    
    @property
    def transaction_id(self) -> str:
        return self._transaction_id
    
    @property
    def state(self) -> TransactionState:
        return self._state
    
    @property
    def is_terminal(self) -> bool:
        """Check if current state is terminal (no more transitions)."""
        return self._state in self.TERMINAL_STATES
    
    @property
    def is_success(self) -> bool:
        """Check if transaction is in a success state."""
        return self._state in {
            TransactionState.CAPTURED,
            TransactionState.SETTLED,
            TransactionState.PARTIALLY_REFUNDED,
            TransactionState.DISPUTE_WON,
        }
    
    @property
    def is_failure(self) -> bool:
        """Check if transaction is in a failure state."""
        return self._state in {
            TransactionState.FAILED,
            TransactionState.DECLINED,
            TransactionState.EXPIRED,
            TransactionState.VOIDED,
            TransactionState.CANCELLED,
            TransactionState.DISPUTE_LOST,
        }
    
    def can_transition(
        self,
        event: TransactionEvent,
        context: Optional[Dict[str, Any]] = None,
    ) -> bool:
        """Check if event can trigger a valid transition from current state."""
        key = (self._state, event)
        rule = self._transitions.get(key)
        
        if rule is None:
            return False
        
        return rule.is_allowed(context)
    
    def get_valid_events(self) -> List[TransactionEvent]:
        """Get list of events valid from current state."""
        valid = []
        for (from_state, event), rule in self._transitions.items():
            if from_state == self._state:
                valid.append(event)
        return valid
    
    def process_event(
        self,
        event: TransactionEvent,
        actor: Optional[str] = None,
        metadata: Optional[Dict[str, Any]] = None,
        context: Optional[Dict[str, Any]] = None,
    ) -> bool:
        """
        Process an event and transition to new state.
        
        Args:
            event: Event to process
            actor: Who/what triggered the event (for audit)
            metadata: Additional data to record
            context: Context for guard condition evaluation
            
        Returns:
            True if transition successful, False otherwise
        """
        with self._lock:
            key = (self._state, event)
            rule = self._transitions.get(key)
            
            if rule is None:
                logger.warning(
                    f"Invalid transition: {self._state.value} + {event.value} "
                    f"for transaction {self._transaction_id}"
                )
                return False
            
            if not rule.is_allowed(context):
                logger.warning(
                    f"Transition guard rejected: {self._state.value} + {event.value} "
                    f"for transaction {self._transaction_id}"
                )
                return False
            
            # Record transition
            transition = StateTransition(
                from_state=self._state,
                to_state=rule.to_state,
                event=event,
                timestamp=datetime.utcnow(),
                actor=actor,
                metadata=metadata or {},
            )
            self._history.append(transition)
            
            # Update state
            old_state = self._state
            self._state = rule.to_state
            
            logger.info(
                f"Transaction {self._transaction_id}: "
                f"{old_state.value} → {self._state.value} (event: {event.value})"
            )
            
            return True
    
    def get_history(self) -> List[StateTransition]:
        """Get full transition history (audit trail)."""
        with self._lock:
            return list(self._history)
    
    def get_history_dicts(self) -> List[Dict[str, Any]]:
        """Get history as list of dictionaries (JSON-serializable)."""
        return [t.to_dict() for t in self.get_history()]
    
    def to_dict(self) -> Dict[str, Any]:
        """Serialize state machine to dictionary."""
        return {
            "transaction_id": self._transaction_id,
            "current_state": self._state.value,
            "is_terminal": self.is_terminal,
            "is_success": self.is_success,
            "is_failure": self.is_failure,
            "valid_events": [e.value for e in self.get_valid_events()],
            "history": self.get_history_dicts(),
        }
    
    @classmethod
    def from_history(
        cls,
        transaction_id: str,
        history: List[StateTransition],
    ) -> "TransactionStateMachine":
        """
        Reconstruct state machine from history.
        
        Useful for loading from database.
        """
        machine = cls(transaction_id)
        
        if history:
            # Replay history to reach current state
            machine._state = history[-1].to_state
            machine._history = list(history)
        
        return machine


# Convenience functions for common flows
def create_credit_card_machine(transaction_id: str) -> TransactionStateMachine:
    """Create state machine for credit card transactions."""
    return TransactionStateMachine(transaction_id)


def create_pix_machine(transaction_id: str) -> TransactionStateMachine:
    """Create state machine for PIX transactions (starts pending)."""
    machine = TransactionStateMachine(transaction_id)
    machine.process_event(TransactionEvent.SUBMIT, actor="system")
    machine.process_event(TransactionEvent.TIMEOUT, actor="system")  # Goes to PENDING
    return machine
