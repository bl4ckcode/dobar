from typing import Dict, Any
from datetime import datetime, timezone, timedelta
import uuid
import logging

from .schemas import (
    ChargeRequestAPI,
    ChargeResponseAPI,
    RefundRequestAPI,
    RefundResponseAPI,
    PaymentStatusResponse,
    PixGenerateRequest,
    PixGenerateResponse,
    ErrorResponse,
    HealthResponse,
    PaymentMethodTypeAPI,
)
from .middleware import (
    RequestContext,
    error_code_to_http_status,
    DPE_VERSION,
)
from .dependencies import (
    payment_store,
    gateway_registry,
    generate_payment_id,
    generate_refund_id,
)

logger = logging.getLogger("dobar.payment.api")


class PaymentRoutes:
    
    @staticmethod
    async def create_charge(request: ChargeRequestAPI) -> tuple[ChargeResponseAPI | ErrorResponse, int]:
        ctx = RequestContext.get_current()
        request_id = ctx.request_id if ctx else str(uuid.uuid4())
        
        cached = payment_store.check_idempotency(request.idempotency_key)
        if cached:
            logger.info(f"[{request_id}] Returning cached response for idempotency key")
            return ChargeResponseAPI(**cached), 200
        
        gateway_result = gateway_registry.get_for_country(request.country)
        if not gateway_result:
            return ErrorResponse(
                error_code="GATEWAY_UNAVAILABLE",
                message=f"No gateway available for country: {request.country}",
            ), 503
        
        gateway_name, gateway = gateway_result
        payment_id = generate_payment_id()
        now = datetime.now(timezone.utc)
        
        try:
            payment_method = request.payment_method
            charge_kwargs: Dict[str, Any] = {
                "amount": request.amount,
                "currency": request.currency,
                "idempotency_key": request.idempotency_key,
                "metadata": {
                    "order_id": request.order_id,
                    "user_id": request.user_id,
                    "bar_id": request.bar_id,
                    **request.metadata,
                },
            }
            
            if payment_method.type == PaymentMethodTypeAPI.CARD:
                charge_kwargs["payment_method"] = {
                    "type": "card",
                    "token": payment_method.token,
                    "installments": payment_method.installments,
                }
            elif payment_method.type == PaymentMethodTypeAPI.PIX:
                charge_kwargs["payment_method"] = {
                    "type": "pix",
                    "pix_key": payment_method.pix_key,
                }
            
            result = await gateway.create_charge(**charge_kwargs)
            
            if result.get("status") == "error":
                error_code = result.get("error_code", "PAYMENT_DECLINED")
                return ErrorResponse(
                    error_code=error_code,
                    message=result.get("message", "Payment failed"),
                    details={
                        "provider": gateway_name,
                        "provider_code": result.get("gateway_code"),
                        "provider_message": result.get("gateway_message"),
                    },
                ), error_code_to_http_status(error_code)
            
            response = ChargeResponseAPI(
                payment_id=payment_id,
                status=result.get("status", "succeeded"),
                provider=gateway_name,
                provider_id=result.get("transaction_id", result.get("id", "")),
                amount=request.amount,
                currency=request.currency,
                created_at=now,
                pix_qr_code=result.get("pix_qr_code"),
                pix_copia_e_cola=result.get("pix_copia_e_cola"),
                pix_expires_at=result.get("pix_expires_at"),
                card_last_four=result.get("card_last_four"),
                card_brand=result.get("card_brand"),
            )
            
            payment_store.store_payment(payment_id, {
                "payment_id": payment_id,
                "status": response.status,
                "provider": gateway_name,
                "provider_id": response.provider_id,
                "amount": request.amount,
                "currency": request.currency,
                "order_id": request.order_id,
                "user_id": request.user_id,
                "bar_id": request.bar_id,
                "refunded_amount": 0.0,
                "created_at": now.isoformat(),
            })
            
            payment_store.store_idempotency(
                request.idempotency_key,
                response.model_dump(mode="json"),
            )
            
            logger.info(f"[{request_id}] Payment {payment_id} created via {gateway_name}")
            return response, 200
            
        except Exception as e:
            logger.exception(f"[{request_id}] Payment failed: {e}")
            return ErrorResponse(
                error_code="PROVIDER_ERROR",
                message=str(e),
                details={"provider": gateway_name},
            ), 502
    
    @staticmethod
    async def create_refund(request: RefundRequestAPI) -> tuple[RefundResponseAPI | ErrorResponse, int]:
        ctx = RequestContext.get_current()
        request_id = ctx.request_id if ctx else str(uuid.uuid4())
        
        cached = payment_store.check_idempotency(request.idempotency_key)
        if cached:
            return RefundResponseAPI(**cached), 200
        
        payment = payment_store.get_payment(request.payment_id)
        if not payment:
            return ErrorResponse(
                error_code="NOT_FOUND",
                message=f"Payment not found: {request.payment_id}",
            ), 404
        
        gateway_name = payment.get("provider")
        gateway = gateway_registry.get(gateway_name)
        if not gateway:
            return ErrorResponse(
                error_code="GATEWAY_UNAVAILABLE",
                message=f"Gateway not available: {gateway_name}",
            ), 503
        
        refund_amount = request.amount or payment["amount"]
        remaining = payment["amount"] - payment.get("refunded_amount", 0)
        
        if refund_amount > remaining:
            return ErrorResponse(
                error_code="INVALID_AMOUNT",
                message=f"Refund amount {refund_amount} exceeds remaining {remaining}",
            ), 400
        
        try:
            result = await gateway.refund_charge(
                charge_id=payment.get("provider_id"),
                amount=refund_amount,
                idempotency_key=request.idempotency_key,
            )
            
            if result.get("status") == "error":
                return ErrorResponse(
                    error_code=result.get("error_code", "PROVIDER_ERROR"),
                    message=result.get("message", "Refund failed"),
                ), 502
            
            refund_id = generate_refund_id()
            now = datetime.now(timezone.utc)
            
            new_refunded = payment.get("refunded_amount", 0) + refund_amount
            new_status = "refunded" if new_refunded >= payment["amount"] else "partially_refunded"
            payment_store.update_payment(request.payment_id, {
                "refunded_amount": new_refunded,
                "status": new_status,
            })
            
            response = RefundResponseAPI(
                refund_id=refund_id,
                payment_id=request.payment_id,
                status="succeeded",
                amount=refund_amount,
                created_at=now,
            )
            
            payment_store.store_refund(refund_id, response.model_dump(mode="json"))
            payment_store.store_idempotency(
                request.idempotency_key,
                response.model_dump(mode="json"),
            )
            
            logger.info(f"[{request_id}] Refund {refund_id} created for payment {request.payment_id}")
            return response, 200
            
        except Exception as e:
            logger.exception(f"[{request_id}] Refund failed: {e}")
            return ErrorResponse(
                error_code="PROVIDER_ERROR",
                message=str(e),
            ), 502
    
    @staticmethod
    async def get_payment(payment_id: str) -> tuple[PaymentStatusResponse | ErrorResponse, int]:
        payment = payment_store.get_payment(payment_id)
        if not payment:
            return ErrorResponse(
                error_code="NOT_FOUND",
                message=f"Payment not found: {payment_id}",
            ), 404
        
        return PaymentStatusResponse(
            payment_id=payment_id,
            status=payment["status"],
            amount=payment["amount"],
            currency=payment["currency"],
            provider=payment["provider"],
            refunded_amount=payment.get("refunded_amount", 0.0),
            created_at=datetime.fromisoformat(payment["created_at"]),
        ), 200


class PixRoutes:
    
    @staticmethod
    async def generate_brcode(request: PixGenerateRequest) -> tuple[PixGenerateResponse | ErrorResponse, int]:
        try:
            from ..pix.brcode import PixBRCode
            
            reference_id = request.reference_id or str(uuid.uuid4())[:8].upper()
            expires_at = datetime.now(timezone.utc) + timedelta(seconds=request.expires_in)
            
            brcode = PixBRCode(
                pix_key=request.pix_key,
                merchant_name=request.merchant_name,
                merchant_city=request.merchant_city,
                amount=request.amount,
                reference_id=reference_id,
                description=request.description,
            )
            
            copia_e_cola = brcode.generate()
            
            return PixGenerateResponse(
                qr_code=copia_e_cola,
                copia_e_cola=copia_e_cola,
                expires_at=expires_at,
                reference_id=reference_id,
            ), 200
            
        except Exception as e:
            logger.exception(f"PIX BR Code generation failed: {e}")
            return ErrorResponse(
                error_code="PROVIDER_ERROR",
                message=f"Failed to generate PIX BR Code: {str(e)}",
            ), 500


class HealthRoutes:
    
    @staticmethod
    async def health_check() -> tuple[HealthResponse, int]:
        gateways = gateway_registry.get_health_status()
        all_healthy = all(gateways.values()) if gateways else True
        
        status = "healthy" if all_healthy else "degraded"
        if not gateways:
            status = "healthy"
        
        return HealthResponse(
            status=status,
            version=DPE_VERSION,
            gateways=gateways,
            timestamp=datetime.now(timezone.utc),
        ), 200
