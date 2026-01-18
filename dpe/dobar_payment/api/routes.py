from typing import Dict, Any
from datetime import datetime, timezone, timedelta
import uuid
import logging
import base64

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
    generate_pix_id,
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
                request_id=request_id,
            ), 503
        
        gateway_name, gateway = gateway_result
        payment_id = generate_payment_id()
        now = datetime.now(timezone.utc)
        
        try:
            payment_method = request.payment_method
            charge_kwargs: Dict[str, Any] = {
                "amount": request.amount_cents / 100.0,
                "currency": request.currency,
                "idempotency_key": request.idempotency_key,
                "metadata": {
                    "order_id": request.order_id,
                    "user_id": request.user_id,
                    "bar_id": request.bar_id,
                    **request.metadata,
                },
            }
            
            if request.customer_info:
                charge_kwargs["customer"] = {
                    "name": request.customer_info.name,
                    "email": request.customer_info.email,
                    "document": request.customer_info.document,
                    "document_type": "CPF" if len(request.customer_info.document) == 11 else "CNPJ",
                }
                if request.customer_info.phone:
                    charge_kwargs["customer"]["phone"] = request.customer_info.phone
            
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
                        "gateway": gateway_name,
                        "gateway_code": result.get("gateway_code"),
                    },
                    request_id=request_id,
                ), error_code_to_http_status(error_code)
            
            response = ChargeResponseAPI(
                payment_id=payment_id,
                status=result.get("status", "succeeded"),
                gateway=gateway_name,
                gateway_id=result.get("transaction_id", result.get("id", "")),
                amount_cents=request.amount_cents,
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
                "gateway": gateway_name,
                "gateway_id": response.gateway_id,
                "amount_cents": request.amount_cents,
                "currency": request.currency,
                "order_id": request.order_id,
                "user_id": request.user_id,
                "bar_id": request.bar_id,
                "refunded_amount_cents": 0,
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
                error_code="GATEWAY_ERROR",
                message=str(e),
                details={"gateway": gateway_name},
                request_id=request_id,
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
                request_id=request_id,
            ), 404
        
        gateway_name = payment.get("gateway")
        gateway = gateway_registry.get(gateway_name)
        if not gateway:
            return ErrorResponse(
                error_code="GATEWAY_ERROR",
                message=f"Gateway not available: {gateway_name}",
                request_id=request_id,
            ), 503
        
        refund_amount_cents = request.amount_cents or payment["amount_cents"]
        remaining = payment["amount_cents"] - payment.get("refunded_amount_cents", 0)
        
        if refund_amount_cents > remaining:
            return ErrorResponse(
                error_code="VALIDATION_ERROR",
                message=f"Refund amount {refund_amount_cents} exceeds remaining {remaining}",
                request_id=request_id,
            ), 400
        
        try:
            result = await gateway.refund_charge(
                charge_id=payment.get("gateway_id"),
                amount=refund_amount_cents / 100.0,
                idempotency_key=request.idempotency_key,
            )
            
            if result.get("status") == "error":
                return ErrorResponse(
                    error_code=result.get("error_code", "GATEWAY_ERROR"),
                    message=result.get("message", "Refund failed"),
                    request_id=request_id,
                ), 502
            
            refund_id = generate_refund_id()
            now = datetime.now(timezone.utc)
            
            new_refunded = payment.get("refunded_amount_cents", 0) + refund_amount_cents
            new_status = "refunded" if new_refunded >= payment["amount_cents"] else "partially_refunded"
            payment_store.update_payment(request.payment_id, {
                "refunded_amount_cents": new_refunded,
                "status": new_status,
            })
            
            response = RefundResponseAPI(
                refund_id=refund_id,
                payment_id=request.payment_id,
                status="succeeded",
                amount_cents=refund_amount_cents,
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
                error_code="GATEWAY_ERROR",
                message=str(e),
                request_id=request_id,
            ), 502
    
    @staticmethod
    async def get_payment(payment_id: str) -> tuple[PaymentStatusResponse | ErrorResponse, int]:
        ctx = RequestContext.get_current()
        request_id = ctx.request_id if ctx else str(uuid.uuid4())
        
        payment = payment_store.get_payment(payment_id)
        if not payment:
            return ErrorResponse(
                error_code="NOT_FOUND",
                message=f"Payment not found: {payment_id}",
                request_id=request_id,
            ), 404
        
        return PaymentStatusResponse(
            payment_id=payment_id,
            status=payment["status"],
            amount_cents=payment["amount_cents"],
            currency=payment["currency"],
            gateway=payment["gateway"],
            refunded_amount_cents=payment.get("refunded_amount_cents", 0),
            created_at=datetime.fromisoformat(payment["created_at"]),
        ), 200


class PixRoutes:
    
    @staticmethod
    async def generate_brcode(request: PixGenerateRequest) -> tuple[PixGenerateResponse | ErrorResponse, int]:
        ctx = RequestContext.get_current()
        request_id = ctx.request_id if ctx else str(uuid.uuid4())
        
        try:
            from ..pix.brcode import PixBRCode
            
            pix_id = generate_pix_id()
            expires_at = datetime.now(timezone.utc) + timedelta(seconds=request.expiration_seconds)
            
            merchant_name = "BARZ"
            merchant_city = "SAO PAULO"
            pix_key = "pix@barz.app"
            
            brcode = PixBRCode(
                key=pix_key,
                receiver_name=merchant_name,
                receiver_city=merchant_city,
                amount=request.amount_cents / 100.0,
                txid=request.order_id,
                description=request.description,
            )
            
            brcode_str = brcode.generate()
            qr_code_base64 = f"data:image/png;base64,{base64.b64encode(brcode_str.encode()).decode()}"
            
            payment_store.store_pix(pix_id, {
                "pix_id": pix_id,
                "order_id": request.order_id,
                "amount_cents": request.amount_cents,
                "brcode": brcode_str,
                "status": "pending",
                "expires_at": expires_at.isoformat(),
            })
            
            return PixGenerateResponse(
                pix_id=pix_id,
                brcode=brcode_str,
                qr_code_base64=qr_code_base64,
                expires_at=expires_at,
                status="pending",
            ), 200
            
        except Exception as e:
            logger.exception(f"PIX BR Code generation failed: {e}")
            return ErrorResponse(
                error_code="GATEWAY_ERROR",
                message=f"Failed to generate PIX BR Code: {str(e)}",
                request_id=request_id,
            ), 500


class HealthRoutes:
    
    @staticmethod
    async def health_check() -> tuple[HealthResponse, int]:
        gateways_health = gateway_registry.get_health_status()
        
        gateway_status: Dict[str, str] = {}
        for name, healthy in gateways_health.items():
            gateway_status[name] = "healthy" if healthy else "degraded"
        
        all_healthy = all(gateways_health.values()) if gateways_health else True
        status = "healthy" if all_healthy else "degraded"
        
        return HealthResponse(
            status=status,
            version=DPE_VERSION,
            gateways=gateway_status,
        ), 200
