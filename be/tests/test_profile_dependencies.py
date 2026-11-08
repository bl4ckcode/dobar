"""C04 profile dependencies: owned benefits, verified contact change, deletion."""
import os
from datetime import datetime, timedelta, timezone
from decimal import Decimal

import pytest

from app.database import database
from app.errors import APIError


def token(uid: int) -> dict:
    from jose import jwt
    key = os.getenv("SECRET_KEY", "test_secret_key_for_testing_only")
    now = datetime.now(timezone.utc)
    t = jwt.encode({"sub": str(uid), "exp": now + timedelta(hours=1), "iat": now, "type": "access"}, key, algorithm="HS256")
    return {"Authorization": f"Bearer {t}"}


async def make_user(tag: str, tier="regular", **kw):
    from app.auth.auth_models import User
    return await database.execute(User.__table__.insert().values(
        firebase_uid=f"fb_{tag}", phone_number=f"+55319{abs(hash(tag)) % 10**8:08d}",
        email=f"{tag}@test.com", is_active=True, subscription_tier=tier,
        email_verified=True, phone_verified=True, **kw))


async def make_venue(n: int, name: str, funded=True, promo_type="cashback", active=True, ended=False):
    from app.bars_and_restaurants.models.relational_models import Bar, BarOwner, Promotion
    from app.bars_and_restaurants.models.wallet_models import BarWallet
    await database.execute(BarOwner.__table__.insert().values(id=9000 + n, name="O", email=f"o{n}@t.com"))
    bid = await database.execute(Bar.__table__.insert().values(name=name, address=f"Rua {n}", owner_id=9000 + n))
    if funded:
        await database.execute(BarWallet.__table__.insert().values(bar_id=bid, available_balance=Decimal("100.00"), reserved_balance=Decimal("0")))
    await database.execute(Promotion.__table__.insert().values(
        bar_id=bid, title=f"Promo {name}", promotion_type=promo_type, discount_type="percentage",
        discount_value=10.0, is_active=active, terms="Somente bebidas",
        end_date=datetime.utcnow() - timedelta(days=1) if ended else None))
    return bid


@pytest.mark.asyncio
class TestBenefits:
    async def test_requires_authentication(self, client):
        assert (await client.get("/me/benefits")).status_code in (401, 403)
        assert (await client.get("/me/benefits/cashback_wallet/venues")).status_code in (401, 403)

    async def test_regular_user_has_no_active_benefits(self, client, cleanup_database):
        uid = await make_user("reg")
        body = (await client.get("/me/benefits", headers=token(uid))).json()
        assert body["active_count"] == 0
        pro = next(b for b in body["benefits"] if b["kind"] == "pro_coupon")
        assert pro["status"] == "unavailable" and pro["unavailable_reason"] == "pro_required"
        cash = next(b for b in body["benefits"] if b["kind"] == "cashback")
        assert cash["quantity"] == {"unit": "brl_cents", "remaining": 0, "limit": None, "used": None, "reserved": None, "pending": 0}
        assert cash["unavailable_reason"] == "zero_balance"
        r = await client.get(f"/me/benefits/{pro['id']}/venues", headers=token(uid))
        assert r.status_code == 403

    async def test_pro_with_eligible_venues(self, client, cleanup_database):
        uid = await make_user("pro", tier="pro")
        good = await make_venue(1, "Bar Bom")
        await make_venue(2, "Sem Fundos", funded=False)
        await make_venue(3, "Desconto", promo_type="discount")
        await make_venue(4, "Inativa", active=False)
        await make_venue(5, "Encerrada", ended=True)
        body = (await client.get("/me/benefits", headers=token(uid))).json()
        pro = next(b for b in body["benefits"] if b["kind"] == "pro_coupon")
        assert pro["status"] == "active" and body["active_count"] == 1
        assert pro["quantity"]["remaining"] == 5 and pro["quantity"]["limit"] == 5
        assert pro["eligibility"]["venue_count"] == 1
        v = (await client.get(f"/me/benefits/{pro['id']}/venues", headers=token(uid))).json()
        assert [x["bar_id"] for x in v["venues"]] == [good]
        assert v["venues"][0]["promotions"][0]["terms"] == "Somente bebidas"
        assert "pro_required" in v["conditions"]

    async def test_navigation_does_not_consume_allowance(self, client, cleanup_database):
        from app.bars_and_restaurants.models.wallet_models import ProCouponUsage
        uid = await make_user("pro2", tier="pro")
        await make_venue(6, "Bar")
        b = (await client.get("/me/benefits", headers=token(uid))).json()["benefits"][0]
        await client.get(f"/me/benefits/{b['id']}/venues", headers=token(uid))
        assert await database.fetch_all(ProCouponUsage.__table__.select()) == []
        again = (await client.get("/me/benefits", headers=token(uid))).json()["benefits"][0]
        assert again["quantity"]["remaining"] == 5

    async def test_exhausted_and_no_venues_are_unavailable(self, client, cleanup_database):
        from app.bars_and_restaurants.models.wallet_models import ProCouponUsage, ProCouponStatus
        from app.bars_and_restaurants.services.pro_coupon_service import current_period_bounds
        uid = await make_user("pro3", tier="pro")
        b = (await client.get("/me/benefits", headers=token(uid))).json()["benefits"][0]
        assert b["unavailable_reason"] == "no_eligible_venues"
        assert (await client.get(f"/me/benefits/{b['id']}/venues", headers=token(uid))).status_code == 409
        await make_venue(7, "Bar")
        key, _, _ = current_period_bounds()
        now = datetime.now(timezone.utc)
        for _ in range(5):
            await database.execute(ProCouponUsage.__table__.insert().values(
                user_id=uid, period_key=key, status=ProCouponStatus.REDEEMED, created_at=now, updated_at=now))
        b = (await client.get("/me/benefits", headers=token(uid))).json()["benefits"][0]
        assert b["status"] == "unavailable" and b["unavailable_reason"] == "allowance_exhausted"

    async def test_cashback_balance_units_and_no_guessed_venues(self, client, cleanup_database):
        from app.bars_and_restaurants.models.wallet_models import UserWallet
        uid = await make_user("cash")
        await database.execute(UserWallet.__table__.insert().values(
            user_id=uid, available_balance=Decimal("12.34"), pending_balance=Decimal("1.00")))
        body = (await client.get("/me/benefits", headers=token(uid))).json()
        cash = next(b for b in body["benefits"] if b["kind"] == "cashback")
        assert cash["status"] == "active" and cash["quantity"]["remaining"] == 1234 and cash["quantity"]["pending"] == 100
        assert body["active_count"] == 1
        assert cash["eligibility"]["venue_filter_supported"] is False
        assert (await client.get("/me/benefits/cashback_wallet/venues", headers=token(uid))).status_code == 409

    async def test_unknown_or_other_period_benefit_is_not_found(self, client, cleanup_database):
        uid = await make_user("pro4", tier="pro")
        assert (await client.get("/me/benefits/pro_coupon:2001-01/venues", headers=token(uid))).status_code == 404

    async def test_benefits_are_scoped_to_caller(self, client, cleanup_database):
        from app.bars_and_restaurants.models.wallet_models import UserWallet
        a = await make_user("a1")
        b = await make_user("b1")
        await database.execute(UserWallet.__table__.insert().values(
            user_id=a, available_balance=Decimal("50.00"), pending_balance=Decimal("0")))
        body = (await client.get("/me/benefits", headers=token(b))).json()
        assert next(x for x in body["benefits"] if x["kind"] == "cashback")["quantity"]["remaining"] == 0


@pytest.fixture
def proof(monkeypatch):
    """Stub the provider: proof_token is looked up in this dict."""
    claims = {}
    import app.auth.contact_change as cc
    def fake(tok):
        if tok not in claims:
            raise APIError.invalid_token("Invalid contact verification proof")
        return claims[tok]
    monkeypatch.setattr(cc, "verify_contact_proof", fake)
    return claims


def fresh(**kw):
    return {"auth_time": int(datetime.now(timezone.utc).timestamp()), "uid": "fb_new", **kw}


@pytest.mark.asyncio
class TestContactChange:
    async def start(self, client, uid, channel="phone", value="+5531988887777"):
        return await client.post("/me/contact-change", json={"channel": channel, "new_value": value}, headers=token(uid))

    async def test_requires_auth_and_validates(self, client, cleanup_database):
        assert (await client.post("/me/contact-change", json={"channel": "phone", "new_value": "+5531988887777"})).status_code in (401, 403)
        uid = await make_user("cc0")
        assert (await self.start(client, uid, "phone", "12345")).status_code == 422
        assert (await self.start(client, uid, "email", "nope")).status_code == 422

    async def test_phone_change_happy_path_revokes_sessions(self, client, cleanup_database, proof):
        from app.auth.auth_models import User, RefreshToken
        uid = await make_user("cc1")
        now = datetime.now(timezone.utc)
        await database.execute(RefreshToken.__table__.insert().values(
            user_id=uid, token="old-refresh", expires_at=now + timedelta(days=5)))
        started = (await self.start(client, uid)).json()
        proof["p1"] = fresh(phone_number="+5531988887777")
        r = await client.post(f"/me/contact-change/{started['request_id']}/confirm", json={"proof_token": "p1"}, headers=token(uid))
        assert r.status_code == 200, r.text
        body = r.json()
        assert body["phone_number"] == "+5531988887777" and body["phone_verified"] is True and body["access_token"]
        user = await database.fetch_one(User.__table__.select().where(User.id == uid))
        assert user["phone_number"] == "+5531988887777" and user["firebase_uid"] == "fb_new"
        old = await database.fetch_one(RefreshToken.__table__.select().where(RefreshToken.token == "old-refresh"))
        assert old["revoked_at"] is not None
        # replay
        r2 = await client.post(f"/me/contact-change/{started['request_id']}/confirm", json={"proof_token": "p1"}, headers=token(uid))
        assert r2.status_code == 401

    async def test_email_requires_verified_matching_claim(self, client, cleanup_database, proof):
        uid = await make_user("cc2")
        s = (await self.start(client, uid, "email", "New@Test.com")).json()
        assert s["new_value"] == "new@test.com"
        proof["unverified"] = fresh(email="new@test.com", email_verified=False)
        proof["other"] = fresh(email="other@test.com", email_verified=True)
        for t in ("unverified", "other", "garbage"):
            r = await client.post(f"/me/contact-change/{s['request_id']}/confirm", json={"proof_token": t}, headers=token(uid))
            assert r.status_code == 401
        proof["ok"] = fresh(email="NEW@test.com", email_verified=True)
        r = await client.post(f"/me/contact-change/{s['request_id']}/confirm", json={"proof_token": "ok"}, headers=token(uid))
        assert r.status_code == 200 and r.json()["email"] == "new@test.com" and r.json()["email_verified"] is True

    async def test_stale_proof_rejected(self, client, cleanup_database, proof):
        uid = await make_user("cc3")
        s = (await self.start(client, uid)).json()
        proof["old"] = {"auth_time": int(datetime.now(timezone.utc).timestamp()) - 3600, "phone_number": "+5531988887777", "uid": "x"}
        r = await client.post(f"/me/contact-change/{s['request_id']}/confirm", json={"proof_token": "old"}, headers=token(uid))
        assert r.status_code == 401

    async def test_uniqueness_on_start_and_confirm(self, client, cleanup_database, proof):
        from app.auth.auth_models import User
        a = await make_user("cc4a")
        b = await make_user("cc4b")
        taken = (await database.fetch_one(User.__table__.select().where(User.id == b)))["phone_number"]
        assert (await self.start(client, a, "phone", taken)).status_code == 409
        assert (await self.start(client, a, "email", "CC4B@test.com")).status_code == 409
        s = (await self.start(client, a)).json()
        # someone else claims the number between start and confirm
        await database.execute(User.__table__.update().where(User.id == b).values(phone_number="+5531988887777"))
        proof["p"] = fresh(phone_number="+5531988887777")
        r = await client.post(f"/me/contact-change/{s['request_id']}/confirm", json={"proof_token": "p"}, headers=token(a))
        assert r.status_code == 409

    async def test_expiry_and_cancellation(self, client, cleanup_database, proof):
        from app.auth.contact_change_models import ContactChangeRequest
        uid = await make_user("cc5")
        s = (await self.start(client, uid)).json()
        await database.execute(ContactChangeRequest.__table__.update().values(expires_at=datetime.now(timezone.utc) - timedelta(seconds=1)))
        proof["p"] = fresh(phone_number="+5531988887777")
        r = await client.post(f"/me/contact-change/{s['request_id']}/confirm", json={"proof_token": "p"}, headers=token(uid))
        assert r.status_code == 401
        s2 = (await self.start(client, uid)).json()
        assert (await client.post(f"/me/contact-change/{s2['request_id']}/cancel", headers=token(uid))).json()["status"] == "cancelled"
        r = await client.post(f"/me/contact-change/{s2['request_id']}/confirm", json={"proof_token": "p"}, headers=token(uid))
        assert r.status_code == 401

    async def test_new_start_supersedes_previous(self, client, cleanup_database, proof):
        uid = await make_user("cc6")
        first = (await self.start(client, uid)).json()
        await self.start(client, uid, "phone", "+5531977776666")
        proof["p"] = fresh(phone_number="+5531988887777")
        r = await client.post(f"/me/contact-change/{first['request_id']}/confirm", json={"proof_token": "p"}, headers=token(uid))
        assert r.status_code == 401

    async def test_other_account_cannot_use_request(self, client, cleanup_database, proof):
        a = await make_user("cc7a")
        b = await make_user("cc7b")
        s = (await self.start(client, a)).json()
        proof["p"] = fresh(phone_number="+5531988887777")
        assert (await client.post(f"/me/contact-change/{s['request_id']}/confirm", json={"proof_token": "p"}, headers=token(b))).status_code == 404
        assert (await client.post(f"/me/contact-change/{s['request_id']}/cancel", headers=token(b))).status_code == 404

    async def test_attempt_limit(self, client, cleanup_database, proof):
        uid = await make_user("cc8")
        s = (await self.start(client, uid)).json()
        codes = [(await client.post(f"/me/contact-change/{s['request_id']}/confirm", json={"proof_token": "bad"}, headers=token(uid))).status_code for _ in range(7)]
        assert codes[:5] == [401] * 5 and codes[5] == 429

    async def test_legacy_put_cannot_change_contacts_but_name_edit_keeps_verification(self, client, cleanup_database):
        from app.auth.auth_models import User
        uid = await make_user("cc9")
        h = token(uid)
        r = await client.put("/me/profile", json={"email": "x@y.com"}, headers=h)
        assert r.status_code == 409 and "contact-change" in r.text
        r = await client.put("/me/profile", json={"phone_number": "+5531900000000"}, headers=h)
        assert r.status_code == 409
        user = await database.fetch_one(User.__table__.select().where(User.id == uid))
        r = await client.put("/me/profile", json={"display_name": "Ana", "email": user["email"].upper()}, headers=h)
        assert r.status_code == 200 and r.json()["display_name"] == "Ana"
        after = await database.fetch_one(User.__table__.select().where(User.id == uid))
        assert after["email_verified"] and after["phone_verified"] and after["email"] == user["email"]


@pytest.mark.asyncio
class TestOrderHistoryVenueName:
    async def test_history_includes_authoritative_bar_name(self, client, cleanup_database):
        from app.bars_and_restaurants.models.relational_models import Order
        uid = await make_user("oh")
        other = await make_user("oh2")
        bid = await make_venue(20, "Bar do Zé")
        now = datetime.utcnow()
        await database.execute(Order.__table__.insert().values(user_id=uid, bar_id=bid, status="pending", total_price=10.0, created_at=now, updated_at=now))
        await database.execute(Order.__table__.insert().values(user_id=other, bar_id=bid, status="pending", total_price=99.0, created_at=now, updated_at=now))
        body = (await client.get("/orders/user/me", headers=token(uid))).json()
        assert [o["bar_name"] for o in body["orders"]] == ["Bar do Zé"]


@pytest.mark.asyncio
class TestDeletion:
    async def test_delete_removes_cards_and_only_caller_data(self, client, cleanup_database):
        from app.payment.models import PaymentCard
        from app.auth.auth_models import User
        a = await make_user("del1")
        b = await make_user("del2")
        for uid, tok in ((a, "tok_a"), (b, "tok_b")):
            await database.execute(PaymentCard.__table__.insert().values(
                user_id=uid, card_token=tok, last_four="4242", brand="visa", exp_month=1, exp_year=2030))
        r = await client.delete("/me/data", headers=token(a))
        assert r.status_code == 200 and r.json()["reference"].startswith("DEL-")
        cards = await database.fetch_all(PaymentCard.__table__.select())
        assert [c["user_id"] for c in cards] == [b]
        assert await database.fetch_one(User.__table__.select().where(User.id == a)) is None
        assert await database.fetch_one(User.__table__.select().where(User.id == b)) is not None
        assert (await client.get("/me/profile", headers=token(a))).status_code in (401, 403, 404)


def _shape(value):
    """Key structure (recursively) so BE output is compared to the shared FE fixture."""
    if isinstance(value, dict):
        return {k: _shape(v) for k, v in value.items()}
    if isinstance(value, list):
        return [_shape(value[0])] if value else []
    return None


@pytest.mark.asyncio
async def test_benefits_wire_shape_matches_shared_fixture(client, cleanup_database):
    import json, pathlib
    fixture = json.loads((pathlib.Path(__file__).parents[2] / "tools/agent_workflow/fixtures/profile-benefits.json").read_text())
    uid = await make_user("wire", tier="pro")
    await make_venue(30, "Bar")
    body = (await client.get("/me/benefits", headers=token(uid))).json()
    expected = {k: v for k, v in fixture["benefits_response"].items()}
    assert _shape(body)["benefits"][0] == _shape(expected)["benefits"][0]
    assert set(body) == set(expected)
    venues = (await client.get(f"/me/benefits/{body['benefits'][0]['id']}/venues", headers=token(uid))).json()
    assert _shape(venues) == _shape(fixture["venues_response"])
