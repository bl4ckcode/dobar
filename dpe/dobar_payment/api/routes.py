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
    TrialSetupRequestAPI,
    TrialSetupResponseAPI,
    CaptureRequestAPI,
    CaptureResponseAPI,
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
        
        proration_credit_cents = None
        if request.proration_info:
            credit = request.proration_info.credit_amount_cents
            effective = request.amount_cents - credit
            proration_credit_cents = credit
            
            if request.proration_info.upgrade_date < request.proration_info.cycle_start:
                return ErrorResponse(
                    error_code="VALIDATION_ERROR",
                    message="upgrade_date cannot be before cycle_start",
                    request_id=request_id,
                ), 400
            
            if request.proration_info.upgrade_date > request.proration_info.cycle_end:
                return ErrorResponse(
                    error_code="VALIDATION_ERROR",
                    message="upgrade_date cannot be after cycle_end",
                    request_id=request_id,
                ), 400
            
            if effective <= 0:
                response = ChargeResponseAPI(
                    payment_id=payment_id,
                    status="credit_applied",
                    gateway="internal",
                    gateway_id="proration_credit",
                    amount_cents=0,
                    currency=request.currency,
                    created_at=now,
                    proration_credit_cents=credit,
                )
                payment_store.store_payment(payment_id, {
                    "payment_id": payment_id,
                    "status": "credit_applied",
                    "gateway": "internal",
                    "gateway_id": "proration_credit",
                    "amount_cents": 0,
                    "original_amount_cents": request.amount_cents,
                    "proration_credit_cents": credit,
                    "currency": request.currency,
                    "order_id": request.order_id,
                    "user_id": request.user_id,
                    "bar_id": request.bar_id,
                    "proration": {
                        "previous_plan": request.proration_info.previous_plan,
                        "new_plan": request.proration_info.new_plan,
                    },
                    "refunded_amount_cents": 0,
                    "created_at": now.isoformat(),
                })
                payment_store.store_idempotency(
                    request.idempotency_key,
                    response.model_dump(mode="json"),
                )
                logger.info(f"[{request_id}] Proration credit fully covers upgrade for payment {payment_id}")
                return response, 200
        
        try:
            payment_method = request.payment_method
            effective_amount = request.amount_cents
            if proration_credit_cents:
                effective_amount = request.amount_cents - proration_credit_cents
            
            charge_kwargs: Dict[str, Any] = {
                "amount": effective_amount / 100.0,
                "currency": request.currency,
                "idempotency_key": request.idempotency_key,
                "metadata": {
                    "order_id": request.order_id,
                    "user_id": request.user_id,
                    "bar_id": request.bar_id,
                    **request.metadata,
                },
            }
            
            if proration_credit_cents:
                charge_kwargs["metadata"]["proration_credit_cents"] = proration_credit_cents
            
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
                proration_credit_cents=proration_credit_cents,
            )
            
            stored = {
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
            }
            if proration_credit_cents:
                stored["proration_credit_cents"] = proration_credit_cents
                stored["effective_amount_cents"] = request.amount_cents - proration_credit_cents
            
            payment_store.store_payment(payment_id, stored)
            
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

    @staticmethod
    async def capture_payment(request: CaptureRequestAPI) -> tuple[CaptureResponseAPI | ErrorResponse, int]:
        ctx = RequestContext.get_current()
        request_id = ctx.request_id if ctx else str(uuid.uuid4())

        cached = payment_store.check_idempotency(request.idempotency_key)
        if cached:
            return CaptureResponseAPI(**cached), 200

        payment = payment_store.get_payment(request.payment_id)
        if not payment:
            return ErrorResponse(
                error_code="NOT_FOUND",
                message=f"Payment not found: {request.payment_id}",
                request_id=request_id,
            ), 404

        capturable_statuses = {"trial_active", "requires_capture", "authorized"}
        if payment.get("status") not in capturable_statuses:
            return ErrorResponse(
                error_code="VALIDATION_ERROR",
                message=f"Payment status '{payment.get('status')}' is not capturable",
                request_id=request_id,
            ), 400

        gateway_name = payment.get("gateway", "stripe")
        gateway = gateway_registry.get(gateway_name)
        if not gateway:
            return ErrorResponse(
                error_code="GATEWAY_UNAVAILABLE",
                message=f"Gateway not available: {gateway_name}",
                request_id=request_id,
            ), 503

        try:
            gateway_id = payment.get("gateway_id", "")
            result = await gateway.capture_charge(
                payment_intent_id=gateway_id,
                amount=request.amount_cents / 100.0,
                idempotency_key=request.idempotency_key,
            )

            if result.get("status") == "error":
                return ErrorResponse(
                    error_code=result.get("error_code", "GATEWAY_ERROR"),
                    message=result.get("message", "Capture failed"),
                    details={"gateway": gateway_name},
                    request_id=request_id,
                ), 502

            now = datetime.now(timezone.utc)
            payment_store.update_payment(request.payment_id, {
                "status": "captured",
                "captured_at": now.isoformat(),
                "captured_amount_cents": request.amount_cents,
            })

            response = CaptureResponseAPI(
                payment_id=request.payment_id,
                status="captured",
                amount_cents=request.amount_cents,
                gateway=gateway_name,
                captured_at=now,
            )

            payment_store.store_idempotency(
                request.idempotency_key,
                response.model_dump(mode="json"),
            )

            logger.info(f"[{request_id}] Captured payment {request.payment_id} via {gateway_name}")
            return response, 200

        except Exception as e:
            logger.exception(f"[{request_id}] Capture failed: {e}")
            return ErrorResponse(
                error_code="GATEWAY_ERROR",
                message=str(e),
                details={"gateway": gateway_name},
                request_id=request_id,
            ), 502


class SubscriptionRoutes:

    @staticmethod
    async def setup_trial(request: TrialSetupRequestAPI) -> tuple[TrialSetupResponseAPI | ErrorResponse, int]:
        ctx = RequestContext.get_current()
        request_id = ctx.request_id if ctx else str(uuid.uuid4())

        cached = payment_store.check_idempotency(request.idempotency_key)
        if cached:
            return TrialSetupResponseAPI(**cached), 200

        stripe_gw = gateway_registry.get("stripe")
        if not stripe_gw:
            return ErrorResponse(
                error_code="GATEWAY_UNAVAILABLE",
                message="Stripe gateway not available for subscription operations",
                request_id=request_id,
            ), 503

        try:
            customer_result = await stripe_gw.create_customer(
                customer={
                    "email": request.customer_email,
                    "name": request.customer_name,
                },
                metadata={
                    "bar_id": request.bar_id,
                    "owner_id": request.owner_id,
                    "plan": request.plan,
                },
            )

            if customer_result.get("status") == "error":
                return ErrorResponse(
                    error_code="GATEWAY_ERROR",
                    message=customer_result.get("message", "Failed to create Stripe customer"),
                    request_id=request_id,
                ), 502

            stripe_customer_id = customer_result["customer_id"]

            setup_result = await stripe_gw.create_setup_intent(
                customer_id=stripe_customer_id,
                payment_method_types=["card"],
                metadata={
                    "trial": "true",
                    "plan": request.plan,
                    "bar_id": request.bar_id,
                    **request.metadata,
                },
            )

            if setup_result.get("status") == "error":
                return ErrorResponse(
                    error_code="GATEWAY_ERROR",
                    message=setup_result.get("message", "Failed to create SetupIntent"),
                    request_id=request_id,
                ), 502

            trial_ends_at = datetime.now(tz=timezone.utc) + timedelta(days=request.trial_days)

            payment_store.store_payment(setup_result["setup_intent_id"], {
                "type": "trial",
                "status": "trial_active",
                "gateway": "stripe",
                "gateway_id": setup_result["setup_intent_id"],
                "stripe_customer_id": stripe_customer_id,
                "payment_method_id": request.payment_method_id,
                "trial_ends_at": trial_ends_at.isoformat(),
                "plan": request.plan,
                "bar_id": request.bar_id,
                "owner_id": request.owner_id,
                "created_at": datetime.now(timezone.utc).isoformat(),
            })

            response = TrialSetupResponseAPI(
                setup_intent_id=setup_result["setup_intent_id"],
                status=setup_result.get("status", "succeeded"),
                client_secret=setup_result.get("client_secret"),
                stripe_customer_id=stripe_customer_id,
                trial_ends_at=trial_ends_at,
                payment_method_id=request.payment_method_id,
            )

            payment_store.store_idempotency(
                request.idempotency_key,
                response.model_dump(mode="json"),
            )

            logger.info(f"[{request_id}] Trial setup for bar {request.bar_id}, plan {request.plan}, ends at {trial_ends_at.isoformat()}")
            return response, 200

        except Exception as e:
            logger.exception(f"[{request_id}] Trial setup failed: {e}")
            return ErrorResponse(
                error_code="GATEWAY_ERROR",
                message=str(e),
                request_id=request_id,
            ), 502


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


class WebhookRoutes:
    
    @staticmethod
    async def process_gateway_webhook(gateway_name: str, payload_bytes: bytes, headers: dict) -> tuple[Dict[str, Any] | ErrorResponse, int]:
        ctx = RequestContext.get_current()
        request_id = ctx.request_id if ctx else str(uuid.uuid4())
        
        import httpx
        import os
        from ..core.webhooks import WebhookHandler, WebhookVerificationError
        
        try:
            stripe_secret = os.getenv("STRIPE_WEBHOOK_SECRET")
            pagarme_secret = os.getenv("PAGARME_WEBHOOK_SECRET") or os.getenv("PAGARME_USERNAME")
            paypal_secret = os.getenv("PAYPAL_WEBHOOK_SECRET")
            
            handler = WebhookHandler(
                stripe_secret=stripe_secret,
                pagarme_secret=pagarme_secret,
                paypal_secret=paypal_secret,
            )
            
            # Verify and parse the payload using core webhooks implementation
            webhook_payload = handler.handle(payload_bytes, headers, gateway=gateway_name)
            
            logger.info(f"[{request_id}] Received valid webhook for {gateway_name}: {webhook_payload.event_type}")
            
            # Determine normalized status based on the gateway's event
            normalized_status = "unknown"
            if webhook_payload.event_type in ["charge.paid", "order.paid"]:
                normalized_status = "succeeded"
            elif webhook_payload.event_type in ["charge.payment_failed", "order.payment_failed", "charge.failed"]:
                normalized_status = "failed"
            elif webhook_payload.event_type in ["charge.refunded"]:
                normalized_status = "refunded"
            else:
                return {"status": "ignored", "reason": f"unhandled_event: {webhook_payload.event_type}"}, 200

            # Map the parsed webhook fields
            data = webhook_payload.data
            
            # Barz-Backend needs 'payment_id' and 'order_id'
            payment_id = webhook_payload.event_id
            order_id = ""
            amount_cents = data.get("amount", 0)
            
            from ..api.schemas import DpeBackendWebhookPayload
            
            # Forward to Barz-Backend
            backend_url = os.getenv("BARZ_BACKEND_URL", "http://localhost:8000")
            backend_secret = os.getenv("DPE_SERVICE_SECRET")
            
            if gateway_name == "stone":
                order_id = data.get("code") or data.get("order", {}).get("code") or ""
                # PagarMe payload data contains the charge or order id, webhook_payload.event_id is just the webhook ID
                payment_id = data.get("id") or payment_id
            
            out_payload = DpeBackendWebhookPayload(
                event=webhook_payload.event_type,
                payment_id=payment_id or "",
                order_id=order_id,
                status=normalized_status,
                amount_cents=amount_cents,
                currency="BRL",
                gateway=gateway_name,
                created_at=webhook_payload.timestamp,
            )
            
            async with httpx.AsyncClient() as client:
                resp = await client.post(
                    f"{backend_url}/payments/webhook",
                    json=out_payload.model_dump(mode="json"),
                    headers={
                        "X-Service-Auth": backend_secret or "",
                        "X-Request-ID": request_id,
                    },
                    timeout=10.0,
                )
                resp.raise_for_status()
                
            logger.info(f"[{request_id}] Successfully forwarded {gateway_name} webhook to Barz-Backend")
            return {"status": "processed"}, 200
            
        except WebhookVerificationError as e:
            logger.warning(f"[{request_id}] Webhook signature verification failed: {e.code}")
            return ErrorResponse(
                error_code="UNAUTHORIZED",
                message="Invalid webhook signature",
                request_id=request_id,
            ), 401
            
        except Exception as e:
            logger.exception(f"[{request_id}] Webhook processing failed: {e}")
            return ErrorResponse(
                error_code="INTERNAL_ERROR",
                message=str(e),
                request_id=request_id,
            ), 500
