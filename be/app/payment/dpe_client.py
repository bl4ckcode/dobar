import os
import httpx
import uuid
from typing import Optional, Dict, Any
from datetime import datetime

DPE_URL = os.getenv("DPE_URL", "http://localhost:8001")
DPE_SERVICE_SECRET = os.getenv("DPE_SERVICE_SECRET", "dev-secret")
DPE_TIMEOUT = float(os.getenv("DPE_TIMEOUT", "30"))


def cents_to_float(cents: int) -> float:
    return cents / 100.0


def float_to_cents(amount: float) -> int:
    return int(round(amount * 100))


class DPEClient:
    def __init__(self, base_url: str = None, service_secret: str = None):
        self.base_url = base_url or DPE_URL
        self.service_secret = service_secret or DPE_SERVICE_SECRET
        self._client: Optional[httpx.AsyncClient] = None
    
    async def _get_client(self) -> httpx.AsyncClient:
        if self._client is None:
            self._client = httpx.AsyncClient(
                base_url=self.base_url,
                timeout=DPE_TIMEOUT,
            )
        return self._client
    
    def _headers(self, idempotency_key: str = None) -> Dict[str, str]:
        headers = {
            "X-Service-Auth": self.service_secret,
            "X-Request-ID": str(uuid.uuid4()),
            "Content-Type": "application/json",
        }
        if idempotency_key:
            headers["X-Idempotency-Key"] = idempotency_key
        return headers
    
    async def charge(
        self,
        order_id: int,
        user_id: int,
        bar_id: int,
        amount: float,
        currency: str,
        country: str,
        payment_method: Dict[str, Any],
        idempotency_key: str,
        metadata: Dict[str, Any] = None,
        description: str = None,
        customer_info: Dict[str, Any] = None,
    ) -> Dict[str, Any]:
        client = await self._get_client()
        
        payload = {
            "order_id": str(order_id),
            "user_id": str(user_id),
            "bar_id": str(bar_id),
            "amount_cents": float_to_cents(amount),
            "currency": currency,
            "country": country,
            "payment_method": payment_method,
            "idempotency_key": idempotency_key,
            "metadata": metadata or {},
        }
        if description:
            payload["description"] = description
        if customer_info:
            payload["customer_info"] = customer_info
        
        response = await client.post(
            "/payments/charge",
            json=payload,
            headers=self._headers(idempotency_key),
        )
        
        if response.status_code == 200:
            data = response.json()
            return {
                "status": data.get("status", "succeeded"),
                "payment_id": data["payment_id"],
                "gateway": data["gateway"],
                "gateway_id": data["gateway_id"],
                "amount": cents_to_float(data["amount_cents"]),
                "currency": data["currency"],
                "created_at": data["created_at"],
                "pix_qr_code": data.get("pix_qr_code"),
                "pix_copia_e_cola": data.get("pix_copia_e_cola"),
                "pix_qr_code_url": data.get("pix_qr_code_url"),
                "pix_expires_at": data.get("pix_expires_at"),
                "card_last_four": data.get("card_last_four"),
                "card_brand": data.get("card_brand"),
                "acquirer_message": data.get("acquirer_message"),
            }
        
        error_data = response.json()
        return {
            "status": "error",
            "error_code": error_data.get("error_code", "UNKNOWN"),
            "message": error_data.get("message", "Payment failed"),
            "details": error_data.get("details"),
            "http_status": response.status_code,
        }
    
    async def refund(
        self,
        payment_id: str,
        amount: float = None,
        reason: str = None,
        idempotency_key: str = None,
    ) -> Dict[str, Any]:
        client = await self._get_client()
        
        idempotency_key = idempotency_key or str(uuid.uuid4())
        
        payload = {
            "payment_id": payment_id,
            "idempotency_key": idempotency_key,
        }
        if amount is not None:
            payload["amount_cents"] = float_to_cents(amount)
        if reason:
            payload["reason"] = reason
        
        response = await client.post(
            "/payments/refund",
            json=payload,
            headers=self._headers(idempotency_key),
        )
        
        if response.status_code == 200:
            data = response.json()
            return {
                "status": "succeeded",
                "refund_id": data["refund_id"],
                "payment_id": data["payment_id"],
                "amount": cents_to_float(data["amount_cents"]),
                "created_at": data["created_at"],
            }
        
        error_data = response.json()
        return {
            "status": "error",
            "error_code": error_data.get("error_code", "UNKNOWN"),
            "message": error_data.get("message", "Refund failed"),
            "http_status": response.status_code,
        }
    
    async def get_payment(self, payment_id: str) -> Dict[str, Any]:
        client = await self._get_client()
        
        response = await client.get(
            f"/payments/{payment_id}",
            headers=self._headers(),
        )
        
        if response.status_code == 200:
            data = response.json()
            return {
                "status": "found",
                "payment_id": data["payment_id"],
                "payment_status": data["status"],
                "amount": cents_to_float(data["amount_cents"]),
                "currency": data["currency"],
                "gateway": data["gateway"],
                "refunded_amount": cents_to_float(data.get("refunded_amount_cents", 0)),
                "created_at": data["created_at"],
            }
        
        return {
            "status": "error",
            "error_code": "NOT_FOUND",
            "message": f"Payment {payment_id} not found",
        }
    
    async def generate_pix(
        self,
        order_id: int,
        amount: float,
        description: str,
        payer_name: str = None,
        payer_document: str = None,
        expires_in: int = 3600,
    ) -> Dict[str, Any]:
        client = await self._get_client()
        
        payload = {
            "order_id": str(order_id),
            "amount_cents": float_to_cents(amount),
            "description": description,
            "expiration_seconds": expires_in,
        }
        if payer_name and payer_document:
            payload["payer_info"] = {
                "name": payer_name,
                "document": payer_document,
            }
        
        response = await client.post(
            "/pix/generate",
            json=payload,
            headers=self._headers(),
        )
        
        if response.status_code == 200:
            data = response.json()
            return {
                "status": "succeeded",
                "pix_id": data["pix_id"],
                "brcode": data["brcode"],
                "qr_code_base64": data["qr_code_base64"],
                "expires_at": data["expires_at"],
                "pix_status": data.get("status", "pending"),
            }
        
        error_data = response.json()
        return {
            "status": "error",
            "error_code": error_data.get("error_code", "GENERATION_FAILED"),
            "message": error_data.get("message", "PIX generation failed"),
        }
    
    async def health_check(self) -> Dict[str, Any]:
        client = await self._get_client()
        
        try:
            response = await client.get("/health")
            if response.status_code == 200:
                return response.json()
        except Exception as e:
            return {"status": "unhealthy", "error": str(e)}
        
        return {"status": "unhealthy"}
    
    async def close(self):
        if self._client:
            await self._client.aclose()
            self._client = None


_dpe_client: Optional[DPEClient] = None

def get_dpe_client() -> DPEClient:
    global _dpe_client
    if _dpe_client is None:
        _dpe_client = DPEClient()
    return _dpe_client

async def close_dpe_client():
    global _dpe_client
    if _dpe_client:
        await _dpe_client.close()
        _dpe_client = None
