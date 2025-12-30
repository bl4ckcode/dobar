"""Tests for transaction state machine."""

import pytest
from datetime import datetime

from dobar_payment.core.state_machine import (
    TransactionState,
    TransactionEvent,
    TransactionStateMachine,
    StateTransition,
    create_credit_card_machine,
    create_pix_machine,
)


class TestTransactionStateMachine:
    """Tests for TransactionStateMachine."""
    
    def test_initial_state(self):
        """Test initial state is CREATED."""
        machine = TransactionStateMachine("txn_123")
        assert machine.state == TransactionState.CREATED
        assert not machine.is_terminal
    
    def test_valid_transition(self):
        """Test valid state transition."""
        machine = TransactionStateMachine("txn_123")
        
        result = machine.process_event(TransactionEvent.SUBMIT)
        assert result is True
        assert machine.state == TransactionState.PROCESSING
    
    def test_invalid_transition(self):
        """Test invalid state transition is rejected."""
        machine = TransactionStateMachine("txn_123")
        
        # Cannot capture before processing
        result = machine.process_event(TransactionEvent.CAPTURE)
        assert result is False
        assert machine.state == TransactionState.CREATED
    
    def test_credit_card_flow(self):
        """Test typical credit card flow."""
        machine = TransactionStateMachine("txn_123")
        
        # Submit -> Processing
        assert machine.process_event(TransactionEvent.SUBMIT)
        assert machine.state == TransactionState.PROCESSING
        
        # Authorize
        assert machine.process_event(TransactionEvent.AUTHORIZE)
        assert machine.state == TransactionState.AUTHORIZED
        
        # Capture
        assert machine.process_event(TransactionEvent.CAPTURE)
        assert machine.state == TransactionState.CAPTURED
        
        assert machine.is_success
        assert not machine.is_terminal
    
    def test_direct_capture_flow(self):
        """Test direct capture flow (no auth)."""
        machine = TransactionStateMachine("txn_123")
        
        machine.process_event(TransactionEvent.SUBMIT)
        machine.process_event(TransactionEvent.CAPTURE)  # Direct capture
        
        assert machine.state == TransactionState.CAPTURED
    
    def test_refund_flow(self):
        """Test refund after capture."""
        machine = TransactionStateMachine("txn_123")
        machine.process_event(TransactionEvent.SUBMIT)
        machine.process_event(TransactionEvent.CAPTURE)
        
        # Full refund
        assert machine.process_event(TransactionEvent.REFUND)
        assert machine.state == TransactionState.REFUNDED
        assert machine.is_terminal
    
    def test_partial_refund_flow(self):
        """Test partial refund flow."""
        machine = TransactionStateMachine("txn_123")
        machine.process_event(TransactionEvent.SUBMIT)
        machine.process_event(TransactionEvent.CAPTURE)
        
        # Partial refund
        assert machine.process_event(TransactionEvent.PARTIAL_REFUND)
        assert machine.state == TransactionState.PARTIALLY_REFUNDED
        assert not machine.is_terminal
        
        # Another partial refund
        assert machine.process_event(TransactionEvent.PARTIAL_REFUND)
        assert machine.state == TransactionState.PARTIALLY_REFUNDED
        
        # Complete refund
        assert machine.process_event(TransactionEvent.REFUND)
        assert machine.state == TransactionState.REFUNDED
        assert machine.is_terminal
    
    def test_failure_flow(self):
        """Test failure handling."""
        machine = TransactionStateMachine("txn_123")
        machine.process_event(TransactionEvent.SUBMIT)
        
        assert machine.process_event(TransactionEvent.FAIL)
        assert machine.state == TransactionState.FAILED
        assert machine.is_failure
    
    def test_decline_flow(self):
        """Test decline handling."""
        machine = TransactionStateMachine("txn_123")
        machine.process_event(TransactionEvent.SUBMIT)
        
        assert machine.process_event(TransactionEvent.DECLINE)
        assert machine.state == TransactionState.DECLINED
        assert machine.is_failure
    
    def test_void_flow(self):
        """Test voiding an authorization."""
        machine = TransactionStateMachine("txn_123")
        machine.process_event(TransactionEvent.SUBMIT)
        machine.process_event(TransactionEvent.AUTHORIZE)
        
        assert machine.process_event(TransactionEvent.VOID)
        assert machine.state == TransactionState.VOIDED
        assert machine.is_terminal
    
    def test_dispute_flow(self):
        """Test dispute handling."""
        machine = TransactionStateMachine("txn_123")
        machine.process_event(TransactionEvent.SUBMIT)
        machine.process_event(TransactionEvent.CAPTURE)
        
        # Dispute initiated
        assert machine.process_event(TransactionEvent.DISPUTE)
        assert machine.state == TransactionState.DISPUTED
        
        # Dispute won
        assert machine.process_event(TransactionEvent.RESOLVE_DISPUTE_WON)
        assert machine.state == TransactionState.DISPUTE_WON
        assert machine.is_terminal
    
    def test_retry_after_failure(self):
        """Test retry after failure."""
        machine = TransactionStateMachine("txn_123")
        machine.process_event(TransactionEvent.SUBMIT)
        machine.process_event(TransactionEvent.FAIL)
        
        # Retry
        assert machine.process_event(TransactionEvent.RETRY)
        assert machine.state == TransactionState.PROCESSING
    
    def test_history_tracking(self):
        """Test transition history is tracked."""
        machine = TransactionStateMachine("txn_123")
        
        machine.process_event(TransactionEvent.SUBMIT, actor="customer")
        machine.process_event(TransactionEvent.AUTHORIZE, actor="gateway")
        machine.process_event(TransactionEvent.CAPTURE, actor="merchant")
        
        history = machine.get_history()
        assert len(history) == 3
        
        assert history[0].from_state == TransactionState.CREATED
        assert history[0].to_state == TransactionState.PROCESSING
        assert history[0].actor == "customer"
        
        assert history[2].to_state == TransactionState.CAPTURED
    
    def test_get_valid_events(self):
        """Test getting valid events from current state."""
        machine = TransactionStateMachine("txn_123")
        
        valid = machine.get_valid_events()
        assert TransactionEvent.SUBMIT in valid
        assert TransactionEvent.CANCEL in valid
        assert TransactionEvent.CAPTURE not in valid
    
    def test_to_dict(self):
        """Test serialization to dict."""
        machine = TransactionStateMachine("txn_123")
        machine.process_event(TransactionEvent.SUBMIT)
        
        data = machine.to_dict()
        assert data["transaction_id"] == "txn_123"
        assert data["current_state"] == "processing"
        assert not data["is_terminal"]


class TestConvenienceFunctions:
    """Tests for convenience factory functions."""
    
    def test_create_credit_card_machine(self):
        """Test credit card machine starts in CREATED state."""
        machine = create_credit_card_machine("txn_123")
        assert machine.state == TransactionState.CREATED
    
    def test_create_pix_machine(self):
        """Test PIX machine starts in PENDING state."""
        machine = create_pix_machine("txn_123")
        assert machine.state == TransactionState.PENDING


class TestStateTransition:
    """Tests for StateTransition dataclass."""
    
    def test_to_dict(self):
        """Test serialization to dict."""
        transition = StateTransition(
            from_state=TransactionState.CREATED,
            to_state=TransactionState.PROCESSING,
            event=TransactionEvent.SUBMIT,
            timestamp=datetime(2024, 12, 29, 12, 0, 0),
            actor="test",
        )
        
        data = transition.to_dict()
        assert data["from_state"] == "created"
        assert data["to_state"] == "processing"
        assert data["event"] == "submit"
        assert data["actor"] == "test"
