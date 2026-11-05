import hashlib
import json
import re
import logging
from datetime import datetime, timedelta
from decimal import Decimal, ROUND_HALF_UP

import httpx

from app.auth.auth_models import User
from app.auth.rbac_models import UserProfile
from app.auth.user_documents import validate_cpf
from app.bars_and_restaurants.models.relational_models import Order, UserDocument
from app.errors import APIError, ErrorCode
from .models import IdempotencyKey, PaymentCard


def operation_key(user_id, operation, key):
    return hashlib.sha256(f"{user_id}:{operation}:{key}".encode()).hexdigest()


def money(value):
    return Decimal(str(value)).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


async def customer_for_payment(db, user_id):
    user = await db.fetch_one(User.__table__.select().where(User.id == user_id))
    profile = await db.fetch_one(UserProfile.__table__.select().where(UserProfile.user_id == user_id))
    document = await db.fetch_one(UserDocument.__table__.select().where(
        UserDocument.user_id == user_id, UserDocument.type == "cpf"
    ).order_by(UserDocument.updated_at.desc(), UserDocument.id.desc()))
    name = (profile["display_name"] or "").strip() if profile else ""
    email = (user["email"] or "").strip() if user else ""
    cpf = re.sub(r"\D", "", document["number"]) if document else ""
    missing = {}
    if not name:
        missing["name"] = ["Complete your name before payment"]
    if not re.fullmatch(r"[^\s@]+@[^\s@]+\.[^\s@]+", email):
        missing["email"] = ["Complete your email before payment"]
    if not validate_cpf(cpf):
        missing["document"] = ["Save a valid CPF before payment"]
    if missing:
        raise APIError.validation_error("Complete your payment profile", details=missing)
    result = {"name": name, "email": email, "document": cpf}
    if user["phone_number"]:
        result["phone"] = user["phone_number"]
    return result


async def resolve_payment_method(db, user_id, method):
    result = {"type": method["type"], "installments": method.get("installments", 1)}
    if result["type"] == "pix":
        return result
    if result["type"] != "card":
        raise APIError.validation_error("Unsupported payment method")
    saved_id = method.get("payment_method_id")
    if saved_id:
        card = await db.fetch_one(PaymentCard.__table__.select().where(
            PaymentCard.id == saved_id, PaymentCard.user_id == user_id
        ))
        if not card:
            raise APIError.not_found("Saved card")
        reference = card["card_token"] or ""
        if not reference.startswith("card_"):
            raise APIError.validation_error("Add this card again before paying", details={"payment_method_id": ["Card must be added again"]})
        result["card_id"] = reference
    else:
        token = (method.get("token") or "").strip()
        if not token.startswith("token_"):
            raise APIError.validation_error("A fresh provider card token or saved card is required")
        result["token"] = token
    return result


def raise_payment_error(result):
    if result.get("status") != "error":
        return
    status = result.get("http_status", 502)
    code = result.get("error_code", "SERVER_UNAVAILABLE")
    message = result.get("message", "Payment service unavailable")
    if status in (400, 422):
        raise APIError.validation_error(message)
    if status == 409:
        raise APIError.conflict(message)
    if status == 402:
        raise APIError.payment_declined(message=message, gateway_code=code)
    if status == 504:
        raise APIError(status_code=504, error_code=ErrorCode.NETWORK_TIMEOUT, message=message)
    raise APIError(status_code=503, error_code=ErrorCode.SERVER_UNAVAILABLE, message=message)


async def owned_order(db, user_id, order_id, lock=False):
    query = Order.__table__.select().where(Order.id == order_id, Order.user_id == user_id)
    if lock:
        query = query.with_for_update()
    order = await db.fetch_one(query)
    if not order:
        raise APIError.not_found("Order")
    return order


async def charge_order(db, dpe, user_id, order_id, method, key=None, expected_bar_id=None, expected_amount=None, currency="BRL", country="BR"):
    method = await resolve_payment_method(db, user_id, method)
    customer = await customer_for_payment(db, user_id)
    path = f"/payments/v2/charge/{order_id}"
    client_key = key or f"order-{order_id}"
    key = operation_key(user_id, path, client_key)
    async with db.transaction():
        order = await owned_order(db, user_id, order_id, lock=True)
        if expected_bar_id is not None and expected_bar_id != order["bar_id"]:
            raise APIError.validation_error("Order venue does not match")
        if expected_amount is not None and money(expected_amount) != money(order["total_price"]):
            raise APIError.validation_error("Order amount has changed")
        if currency != "BRL" or country != "BR":
            raise APIError.validation_error("Brazilian orders require BRL")
        fingerprint = hashlib.sha256(json.dumps({"method": method, "amount": str(money(order["total_price"]))}, sort_keys=True).encode()).hexdigest()
        cached = await db.fetch_one(IdempotencyKey.__table__.select().where(IdempotencyKey.key == key))
        if cached:
            body = cached["response_body"]
            if body.get("fingerprint") != fingerprint:
                raise APIError.conflict("Payment retry differs from the original attempt")
            if body.get("result") and body["result"].get("http_status", 200) < 500:
                raise_payment_error(body["result"])
                result = dict(body["result"])
                if order["payment_status"] == "paid":
                    result["status"] = "succeeded"
                return result
        if order["payment_status"] == "paid":
            raise APIError(status_code=409, error_code=ErrorCode.ORDER_ALREADY_PAID)
        if order["status"] in ("cancelled", "expired"):
            raise APIError.conflict("Order is no longer payable")
        attempts = await db.fetch_all(IdempotencyKey.__table__.select().where(
            IdempotencyKey.user_id == user_id, IdempotencyKey.request_path == path,
            IdempotencyKey.key != key
        ))
        for attempt in attempts:
            previous = attempt["response_body"].get("result", {})
            if previous.get("status") not in ("error", "failed", "declined") or previous.get("http_status", 200) >= 500:
                raise APIError.conflict("Resume the existing payment attempt before starting another")
        if not cached:
            await db.execute(IdempotencyKey.__table__.insert().values(
                key=key, user_id=user_id, request_path=path, response_status=202,
                response_body={"fingerprint": fingerprint, "client_key": client_key},
                created_at=datetime.utcnow(), expires_at=datetime.utcnow() + timedelta(days=1)
            ))
    try:
        result = await dpe.charge(
            order_id=order_id, user_id=user_id, bar_id=order["bar_id"],
            amount=money(order["total_price"]), currency="BRL", country="BR",
            payment_method=method, customer_info=customer, idempotency_key=key,
            metadata={"order_id": str(order_id), "bar_id": str(order["bar_id"])},
        )
    except httpx.TimeoutException:
        raise APIError(status_code=504, error_code=ErrorCode.NETWORK_TIMEOUT,
                       message="Payment outcome is unknown; retry this payment attempt")
    except httpx.HTTPError:
        raise APIError(status_code=503, error_code=ErrorCode.SERVER_UNAVAILABLE,
                       message="Payment service unavailable; retry this payment attempt")
    async with db.transaction():
        current = await owned_order(db, user_id, order_id, lock=True)
        await db.execute(IdempotencyKey.__table__.update().where(IdempotencyKey.key == key).values(
            response_status=result.get("http_status", 200),
            response_body={"fingerprint": fingerprint, "client_key": client_key, "result": result}
        ))
        if current["payment_status"] != "paid":
            payment_status = "paid" if result.get("status") == "succeeded" else (
                "failed" if result.get("status") in ("failed", "declined") or result.get("http_status") == 402 else "pending")
            values = {"payment_status": payment_status, "updated_at": datetime.utcnow()}
            if result.get("payment_id"):
                values["payment_id"] = result["payment_id"]
            await db.execute(Order.__table__.update().where(Order.id == order_id).values(**values))
    raise_payment_error(result)
    if result.get("status") == "succeeded":
        await settle_order_rewards(db, order)
        await publish_payment(order, "paid")
    return result


async def settle_order_rewards(db, order):
    from app.bars_and_restaurants.models.wallet_models import (
        ProCouponUsage, ProCouponStatus, CashbackLedger, CashbackType,
        CashbackStatus, FundingSource, UserWallet,
    )
    async with db.transaction():
        current_order = await owned_order(db, order["user_id"], order["id"], lock=True)
        if current_order["payment_status"] != "paid":
            return
        reservations = await db.fetch_all(ProCouponUsage.__table__.select().where(
            ProCouponUsage.order_id == order["id"], ProCouponUsage.status == ProCouponStatus.RESERVED
        ))
        if not reservations:
            return
        amount = sum((Decimal(str(row["cashback_amount"] or 0)) for row in reservations), Decimal(0))
        ledger_id = None
        if amount > 0:
            await db.fetch_one(User.__table__.select().where(User.id == order["user_id"]).with_for_update())
            existing = await db.fetch_one(CashbackLedger.__table__.select().where(
                CashbackLedger.order_id == order["id"], CashbackLedger.type == CashbackType.EARN
            ))
            if existing:
                ledger_id = existing["id"]
            else:
                now = datetime.utcnow()
                ledger_id = await db.execute(CashbackLedger.__table__.insert().values(
                    user_id=order["user_id"], order_id=order["id"], bar_id=order["bar_id"],
                    amount=amount, type=CashbackType.EARN, funded_by=FundingSource.BAR,
                    status=CashbackStatus.PENDING, created_at=now, expires_at=now + timedelta(days=90),
                ))
                wallet = await db.fetch_one(UserWallet.__table__.select().where(UserWallet.user_id == order["user_id"]))
                if wallet:
                    await db.execute(UserWallet.__table__.update().where(UserWallet.user_id == order["user_id"]).values(
                        pending_balance=UserWallet.pending_balance + amount, last_updated=now
                    ))
                else:
                    await db.execute(UserWallet.__table__.insert().values(user_id=order["user_id"],
                        available_balance=0, pending_balance=amount, last_updated=now))
        await db.execute(ProCouponUsage.__table__.update().where(
            ProCouponUsage.id.in_([row["id"] for row in reservations])
        ).values(status=ProCouponStatus.REDEEMED, cashback_ledger_id=ledger_id, updated_at=datetime.utcnow()))


async def update_attempt_status(db, order_id, payment_id, provider_status):
    attempts = await db.fetch_all(IdempotencyKey.__table__.select().where(
        IdempotencyKey.request_path == f"/payments/v2/charge/{order_id}"
    ))
    for attempt in attempts:
        body = dict(attempt["response_body"] or {})
        result = dict(body.get("result") or {})
        if result.get("payment_id") != payment_id or result.get("status") == "succeeded":
            continue
        result["status"] = provider_status
        body["result"] = result
        await db.execute(IdempotencyKey.__table__.update().where(IdempotencyKey.id == attempt["id"]).values(response_body=body))


async def publish_payment(order, status):
    from app.bars_and_restaurants.services.connection_manager import manager
    event = {"type": "payment_status_update", "order_id": order["id"], "bar_id": order["bar_id"], "payment_status": status}
    try:
        await manager.notify_bar(order["bar_id"], event)
        await manager.notify_order(order["id"], event)
    except Exception:
        logging.getLogger(__name__).warning("Payment notification failed for order %s", order["id"])
