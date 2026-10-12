from typing import Dict, Any, Optional, Callable, Awaitable
from dataclasses import dataclass, field
from datetime import datetime, timezone
from enum import Enum
import asyncio
import uuid
import logging

from .brcode import PixBRCode, PixKeyType, parse_brcode

logger = logging.getLogger("dobar.payment.pix")


class PixTransactionStatus(str, Enum):
    PENDING = "pending"
    ACTIVE = "active"
    COMPLETED = "completed"
    EXPIRED = "expired"
    CANCELLED = "cancelled"


@dataclass
class PixCharge:
    id: str
    txid: str
    key: str
    amount: float
    brcode: str
    status: PixTransactionStatus = PixTransactionStatus.PENDING
    payer_name: Optional[str] = None
    payer_document: Optional[str] = None
    end_to_end_id: Optional[str] = None
    paid_at: Optional[datetime] = None
    expires_at: Optional[datetime] = None
    created_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))
    metadata: Dict[str, Any] = field(default_factory=dict)
    
    def to_dict(self) -> Dict[str, Any]:
        return {
            "id": self.id,
            "txid": self.txid,
            "key": self.key,
            "amount": self.amount,
            "brcode": self.brcode,
            "status": self.status.value,
            "payer_name": self.payer_name,
            "payer_document": self.payer_document,
            "end_to_end_id": self.end_to_end_id,
            "paid_at": self.paid_at.isoformat() if self.paid_at else None,
            "expires_at": self.expires_at.isoformat() if self.expires_at else None,
            "created_at": self.created_at.isoformat(),
            "metadata": self.metadata,
        }


WebhookHandler = Callable[[PixCharge], Awaitable[None]]


class PixDirectGateway:
    def __init__(
        self,
        receiver_name: str,
        receiver_city: str,
        pix_key: str,
        psp_api_url: Optional[str] = None,
        psp_client_id: Optional[str] = None,
        psp_client_secret: Optional[str] = None,
    ):
        self._receiver_name = receiver_name
        self._receiver_city = receiver_city
        self._pix_key = pix_key
        self._psp_api_url = psp_api_url
        self._psp_client_id = psp_client_id
        self._psp_client_secret = psp_client_secret
        self._charges: Dict[str, PixCharge] = {}
        self._webhook_handlers: list[WebhookHandler] = []
        self._reconciliation_tasks: Dict[str, asyncio.Task] = {}
    
    async def create_charge(
        self,
        amount: float,
        txid: Optional[str] = None,
        description: Optional[str] = None,
        expires_in_seconds: int = 3600,
        metadata: Optional[Dict[str, Any]] = None,
    ) -> PixCharge:
        charge_id = str(uuid.uuid4())
        txid = txid or f"DOBAR{charge_id[:8].upper()}"
        
        brcode_obj = PixBRCode(
            key=self._pix_key,
            receiver_name=self._receiver_name,
            receiver_city=self._receiver_city,
            amount=amount,
            txid=txid,
            description=description,
            single_transaction=True,
        )
        
        expires_at = datetime.now(timezone.utc)
        from datetime import timedelta
        expires_at = expires_at + timedelta(seconds=expires_in_seconds)
        
        charge = PixCharge(
            id=charge_id,
            txid=txid,
            key=self._pix_key,
            amount=amount,
            brcode=brcode_obj.generate(),
            status=PixTransactionStatus.ACTIVE,
            expires_at=expires_at,
            metadata=metadata or {},
        )
        
        self._charges[charge_id] = charge
        self._start_expiration_task(charge_id, expires_in_seconds)
        
        logger.info(f"PIX charge created: {charge_id} amount={amount}")
        return charge
    
    async def get_charge(self, charge_id: str) -> Optional[PixCharge]:
        return self._charges.get(charge_id)
    
    async def get_charge_by_txid(self, txid: str) -> Optional[PixCharge]:
        for charge in self._charges.values():
            if charge.txid == txid:
                return charge
        return None
    
    async def cancel_charge(self, charge_id: str) -> Optional[PixCharge]:
        charge = self._charges.get(charge_id)
        if not charge:
            return None
        if charge.status not in (PixTransactionStatus.PENDING, PixTransactionStatus.ACTIVE):
            return charge
        charge.status = PixTransactionStatus.CANCELLED
        self._cancel_expiration_task(charge_id)
        logger.info(f"PIX charge cancelled: {charge_id}")
        return charge
    
    async def process_webhook(self, payload: Dict[str, Any]) -> Optional[PixCharge]:
        pix_data = payload.get("pix", [])
        if not pix_data:
            return None
        
        for pix_payment in pix_data:
            txid = pix_payment.get("txid")
            end_to_end_id = pix_payment.get("endToEndId")
            payer_info = pix_payment.get("pagador", {})
            
            charge = await self.get_charge_by_txid(txid)
            if not charge:
                continue
            
            charge.status = PixTransactionStatus.COMPLETED
            charge.end_to_end_id = end_to_end_id
            charge.payer_name = payer_info.get("nome")
            charge.payer_document = payer_info.get("cpf") or payer_info.get("cnpj")
            charge.paid_at = datetime.now(timezone.utc)
            
            self._cancel_expiration_task(charge.id)
            
            for handler in self._webhook_handlers:
                try:
                    await handler(charge)
                except Exception as e:
                    logger.exception(f"Webhook handler error: {e}")
            
            logger.info(f"PIX charge completed: {charge.id} e2e={end_to_end_id}")
            return charge
        
        return None
    
    def on_payment(self, handler: WebhookHandler) -> None:
        self._webhook_handlers.append(handler)
    
    async def list_charges(
        self,
        status: Optional[PixTransactionStatus] = None,
        limit: int = 50,
    ) -> list[PixCharge]:
        charges = list(self._charges.values())
        if status:
            charges = [c for c in charges if c.status == status]
        charges.sort(key=lambda c: c.created_at, reverse=True)
        return charges[:limit]
    
    async def reconcile(self, external_payments: list[Dict[str, Any]]) -> Dict[str, Any]:
        matched = 0
        unmatched = []
        
        for payment in external_payments:
            txid = payment.get("txid")
            charge = await self.get_charge_by_txid(txid)
            if charge and charge.status == PixTransactionStatus.ACTIVE:
                charge.status = PixTransactionStatus.COMPLETED
                charge.end_to_end_id = payment.get("endToEndId")
                charge.paid_at = datetime.now(timezone.utc)
                matched += 1
            else:
                unmatched.append(payment)
        
        return {
            "matched": matched,
            "unmatched": len(unmatched),
            "unmatched_payments": unmatched,
        }
    
    def _start_expiration_task(self, charge_id: str, expires_in: int) -> None:
        async def expire():
            await asyncio.sleep(expires_in)
            charge = self._charges.get(charge_id)
            if charge and charge.status == PixTransactionStatus.ACTIVE:
                charge.status = PixTransactionStatus.EXPIRED
                logger.info(f"PIX charge expired: {charge_id}")
        
        task = asyncio.create_task(expire())
        self._reconciliation_tasks[charge_id] = task
    
    def _cancel_expiration_task(self, charge_id: str) -> None:
        task = self._reconciliation_tasks.pop(charge_id, None)
        if task and not task.done():
            task.cancel()
    
    async def health_check(self) -> Dict[str, Any]:
        return {
            "status": "healthy",
            "gateway": "pix_direct",
            "receiver": self._receiver_name,
            "active_charges": len([c for c in self._charges.values() if c.status == PixTransactionStatus.ACTIVE]),
        }
