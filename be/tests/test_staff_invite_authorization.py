"""
Authorization and lifecycle tests for the two staff invitation endpoints:

* ``POST /bars/{bar_id}/staff/invite``  (bar in the URL)
* ``POST /staff/invite``                (compatibility route, bar in the body)

Both must authorize with the same resolver (role defaults + the membership's
custom permissions, ``staff:manage`` required, at exactly the bar being
invited to) and both must create invitations that stay ``pending`` until the
invited, authenticated user accepts them within the 7-day expiry.
"""

import json
from datetime import datetime, timedelta

import pytest

from conftest import create_test_token, test_database
from app.auth.auth_models import User
from app.auth.rbac_models import BarStaff, StaffInvitation
from app.bars_and_restaurants.models.relational_models import Bar


pytestmark = pytest.mark.asyncio

ROUTES = ["url", "compat"]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_counter = {"n": 0}


def _next():
    _counter["n"] += 1
    return _counter["n"]


async def make_user(email=None, phone=None, *, email_verified=True, phone_verified=False,
                    no_phone=False):
    n = _next()
    email = email or f"user{n}@example.com"
    phone = None if no_phone else (phone or f"+55119{n:08d}")
    user_id = await test_database.execute(User.__table__.insert().values(
        firebase_uid=f"uid-{n}",
        email=email,
        phone_number=phone,
        is_active=True,
        email_verified=email_verified,
        phone_verified=phone_verified,
    ))
    return {"id": user_id, "email": email, "phone": phone}


async def make_bar(owner_id, name):
    return await test_database.execute(Bar.__table__.insert().values(
        name=name,
        address=f"{_next()} {name} St",
        phone_number="+5511000000000",
        email=f"{name.lower().replace(' ', '')}@bar.test",
        owner_id=owner_id,
    ))


async def add_staff(user_id, bar_id, role, custom_permissions=None, is_active=True):
    if isinstance(custom_permissions, list):
        custom_permissions = json.dumps(custom_permissions)
    return await test_database.execute(BarStaff.__table__.insert().values(
        user_id=user_id,
        bar_id=bar_id,
        role=role,
        custom_permissions=custom_permissions,
        is_active=is_active,
    ))


def headers_for(user, **extra):
    return {"Authorization": f"Bearer {create_test_token(user['id'])}", **extra}


async def invite(client, route, bar_id, user, contact, role="staff", headers=None, params=None):
    headers = headers or headers_for(user)
    if route == "url":
        return await client.post(
            f"/bars/{bar_id}/staff/invite",
            json={"contact": contact, "role": role},
            headers=headers,
            params=params,
        )
    return await client.post(
        "/staff/invite",
        json={"bar_id": bar_id, "contact": contact, "role": role},
        headers=headers,
        params=params,
    )


async def invitations_for(bar_id=None):
    query = StaffInvitation.__table__.select()
    if bar_id is not None:
        query = query.where(StaffInvitation.bar_id == bar_id)
    return await test_database.fetch_all(query)


async def active_membership(user_id, bar_id):
    return await test_database.fetch_one(BarStaff.__table__.select().where(
        (BarStaff.user_id == user_id)
        & (BarStaff.bar_id == bar_id)
        & (BarStaff.is_active == True)  # noqa: E712
    ))


@pytest.fixture
async def venues(client, test_bar_owner_in_db):
    """Two independent venues, A and B."""
    owner_ref = test_bar_owner_in_db["id"]
    return {
        "a": await make_bar(owner_ref, "Venue A"),
        "b": await make_bar(owner_ref, "Venue B"),
    }


# ---------------------------------------------------------------------------
# Users WITH permission
# ---------------------------------------------------------------------------

@pytest.mark.parametrize("route", ROUTES)
@pytest.mark.parametrize("role", ["owner", "admin"])
async def test_role_with_staff_manage_can_invite(client, venues, route, role):
    inviter = await make_user()
    await add_staff(inviter["id"], venues["a"], role)

    resp = await invite(client, route, venues["a"], inviter, "new.hire@example.com")

    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["bar_id"] == venues["a"]
    assert body["status"] == "pending"
    assert body["email"] == "new.hire@example.com"
    assert body["role"] == "staff"

    rows = await invitations_for()
    assert len(rows) == 1
    assert rows[0]["bar_id"] == venues["a"]
    assert rows[0]["invited_by_id"] == inviter["id"]
    assert rows[0]["status"] == "pending"


@pytest.mark.parametrize("route", ROUTES)
@pytest.mark.parametrize("role", ["cashier", "staff", "manager"])
async def test_custom_staff_manage_permission_is_honored(client, venues, route, role):
    inviter = await make_user()
    await add_staff(inviter["id"], venues["a"], role, custom_permissions=["staff:manage"])

    resp = await invite(client, route, venues["a"], inviter, "+5511987654321")

    assert resp.status_code == 200, resp.text
    assert resp.json()["phone"] == "+5511987654321"
    assert resp.json()["status"] == "pending"
    assert len(await invitations_for(venues["a"])) == 1


@pytest.mark.parametrize("route", ROUTES)
async def test_both_routes_emit_the_same_bar_context_headers(client, venues, route):
    inviter = await make_user()
    await add_staff(inviter["id"], venues["a"], "cashier", custom_permissions=["staff:manage"])

    resp = await invite(client, route, venues["a"], inviter, "hdr@example.com")

    assert resp.status_code == 200, resp.text
    assert resp.headers["X-Bar-Id"] == str(venues["a"])
    assert resp.headers["X-Bar-Role"] == "cashier"
    assert "staff:manage" in resp.headers["X-Bar-Permissions"].split(",")


@pytest.mark.parametrize("route", ROUTES)
async def test_both_routes_return_the_same_payload_shape(client, venues, route):
    inviter = await make_user()
    await add_staff(inviter["id"], venues["a"], "owner")

    resp = await invite(client, route, venues["a"], inviter, "shape@example.com", role="admin")

    assert resp.status_code == 200, resp.text
    assert set(resp.json()) == {
        "id", "bar_id", "email", "phone", "role", "status", "invitation_code", "expires_at",
    }


# ---------------------------------------------------------------------------
# Users WITHOUT permission
# ---------------------------------------------------------------------------

@pytest.mark.parametrize("route", ROUTES)
@pytest.mark.parametrize("role", ["manager", "cashier", "staff"])
async def test_role_without_staff_manage_is_rejected(client, venues, route, role):
    # MANAGER does not hold staff:manage by default. The compat route used to
    # admit managers through a role-level shortcut; it now follows permissions.
    inviter = await make_user()
    await add_staff(inviter["id"], venues["a"], role)

    resp = await invite(client, route, venues["a"], inviter, "nope@example.com")

    assert resp.status_code == 403, resp.text
    assert "staff:manage" in resp.text
    assert await invitations_for() == []


@pytest.mark.parametrize("route", ROUTES)
async def test_unrelated_custom_permissions_do_not_grant_invite(client, venues, route):
    inviter = await make_user()
    await add_staff(
        inviter["id"], venues["a"], "cashier",
        custom_permissions=["staff:view", "menu:edit"],
    )

    resp = await invite(client, route, venues["a"], inviter, "nope@example.com")

    assert resp.status_code == 403, resp.text
    assert await invitations_for() == []


@pytest.mark.parametrize("route", ROUTES)
async def test_malformed_custom_permissions_fall_back_to_role_defaults(client, venues, route):
    inviter = await make_user()
    await add_staff(inviter["id"], venues["a"], "cashier", custom_permissions="not json")

    resp = await invite(client, route, venues["a"], inviter, "nope@example.com")

    assert resp.status_code == 403, resp.text
    assert await invitations_for() == []


@pytest.mark.parametrize("route", ROUTES)
async def test_inactive_membership_with_custom_permission_is_rejected(client, venues, route):
    inviter = await make_user()
    await add_staff(
        inviter["id"], venues["a"], "admin",
        custom_permissions=["staff:manage"], is_active=False,
    )

    resp = await invite(client, route, venues["a"], inviter, "nope@example.com")

    assert resp.status_code == 403, resp.text
    assert await invitations_for() == []


@pytest.mark.parametrize("route", ROUTES)
async def test_non_member_is_rejected(client, venues, route):
    outsider = await make_user()

    resp = await invite(client, route, venues["a"], outsider, "nope@example.com")

    assert resp.status_code == 403, resp.text
    assert await invitations_for() == []


@pytest.mark.parametrize("route", ROUTES)
async def test_unauthenticated_is_rejected(client, venues, route):
    if route == "url":
        resp = await client.post(
            f"/bars/{venues['a']}/staff/invite",
            json={"contact": "x@example.com", "role": "staff"},
        )
    else:
        resp = await client.post(
            "/staff/invite",
            json={"bar_id": venues["a"], "contact": "x@example.com", "role": "staff"},
        )

    assert resp.status_code == 401, resp.text
    assert await invitations_for() == []


@pytest.mark.parametrize("route", ROUTES)
async def test_only_owner_can_invite_an_owner(client, venues, route):
    admin = await make_user()
    await add_staff(admin["id"], venues["a"], "admin")

    resp = await invite(client, route, venues["a"], admin, "boss@example.com", role="owner")

    assert resp.status_code == 403, resp.text
    assert await invitations_for() == []


# ---------------------------------------------------------------------------
# Users authorized at a DIFFERENT venue
# ---------------------------------------------------------------------------

@pytest.mark.parametrize("route", ROUTES)
async def test_permission_at_other_venue_does_not_carry_over(client, venues, route):
    # Owner at A, no membership at B.
    inviter = await make_user()
    await add_staff(inviter["id"], venues["a"], "owner")

    resp = await invite(client, route, venues["b"], inviter, "nope@example.com")

    assert resp.status_code == 403, resp.text
    assert await invitations_for() == []


@pytest.mark.parametrize("route", ROUTES)
async def test_custom_permission_at_other_venue_does_not_carry_over(client, venues, route):
    # Custom staff:manage at A, plain cashier at B.
    inviter = await make_user()
    await add_staff(inviter["id"], venues["a"], "cashier", custom_permissions=["staff:manage"])
    await add_staff(inviter["id"], venues["b"], "cashier")

    resp = await invite(client, route, venues["b"], inviter, "nope@example.com")

    assert resp.status_code == 403, resp.text
    assert await invitations_for() == []


@pytest.mark.parametrize("route", ROUTES)
async def test_bar_id_in_header_or_query_cannot_redirect_authorization(client, venues, route):
    """Authorized at A, targeting B: pointing X-Bar-Id / ?bar_id= at A must
    not authorize the invite to B on either route."""
    inviter = await make_user()
    await add_staff(inviter["id"], venues["a"], "owner")

    resp = await invite(
        client, route, venues["b"], inviter, "nope@example.com",
        headers=headers_for(inviter, **{"X-Bar-Id": str(venues["a"])}),
        params={"bar_id": venues["a"]},
    )

    assert resp.status_code == 403, resp.text
    assert await invitations_for() == []


async def test_compat_body_bar_id_is_the_bar_that_is_authorized_and_written(client, venues):
    """The compat route resolves the body bar_id exactly like the URL bar_id:
    a stray X-Bar-Id / ?bar_id= for another bar neither grants nor blocks."""
    inviter = await make_user()
    await add_staff(inviter["id"], venues["b"], "admin")  # only at B

    resp = await client.post(
        "/staff/invite",
        json={"bar_id": venues["b"], "contact": "ok@example.com", "role": "staff"},
        headers=headers_for(inviter, **{"X-Bar-Id": str(venues["a"])}),
        params={"bar_id": venues["a"]},
    )

    assert resp.status_code == 200, resp.text
    assert resp.json()["bar_id"] == venues["b"]
    assert resp.headers["X-Bar-Id"] == str(venues["b"])
    rows = await invitations_for()
    assert [r["bar_id"] for r in rows] == [venues["b"]]


# ---------------------------------------------------------------------------
# Pending until the authenticated invitee accepts (7-day expiry)
# ---------------------------------------------------------------------------

async def _owner_at(bar_id):
    owner = await make_user()
    await add_staff(owner["id"], bar_id, "owner")
    return owner


@pytest.mark.parametrize("route", ROUTES)
async def test_invitation_expires_seven_days_after_creation(client, venues, route):
    owner = await _owner_at(venues["a"])

    before = datetime.utcnow()
    resp = await invite(client, route, venues["a"], owner, "ttl@example.com")
    after = datetime.utcnow()

    assert resp.status_code == 200, resp.text
    row = (await invitations_for())[0]
    assert before + timedelta(days=7) <= row["expires_at"] <= after + timedelta(days=7)


@pytest.mark.parametrize("route", ROUTES)
async def test_existing_user_is_not_added_until_they_accept(client, venues, route):
    owner = await _owner_at(venues["a"])
    invitee = await make_user(email="invitee@example.com")

    resp = await invite(client, route, venues["a"], owner, invitee["email"], role="cashier")
    assert resp.status_code == 200, resp.text
    assert resp.json()["status"] == "pending"
    code = resp.json()["invitation_code"]

    # Still pending; no membership; no bar access.
    assert (await invitations_for())[0]["status"] == "pending"
    assert await active_membership(invitee["id"], venues["a"]) is None
    my_bars = await client.get("/me/bars", headers=headers_for(invitee))
    assert my_bars.status_code == 200
    assert my_bars.json() == []

    # The invitee sees it as pending.
    pending = await client.get("/me/bars/invitations/pending", headers=headers_for(invitee))
    assert pending.status_code == 200
    assert [p["invitation_code"] for p in pending.json()] == [code]

    # The invitee accepts.
    accept = await client.post(
        "/me/bars/accept-invitation",
        json={"invitation_code": code},
        headers=headers_for(invitee),
    )
    assert accept.status_code == 200, accept.text
    assert accept.json()["role"] == "cashier"

    row = (await invitations_for())[0]
    assert row["status"] == "accepted"
    assert row["accepted_by_user_id"] == invitee["id"]
    membership = await active_membership(invitee["id"], venues["a"])
    assert membership is not None
    assert membership["role"] == "cashier"


@pytest.mark.parametrize("route", ROUTES)
async def test_removed_staff_is_not_reactivated_by_reinvite(client, venues, route):
    owner = await _owner_at(venues["a"])
    former = await make_user(email="former@example.com")
    await add_staff(former["id"], venues["a"], "manager", is_active=False)

    resp = await invite(client, route, venues["a"], owner, former["email"])

    assert resp.status_code == 200, resp.text
    assert resp.json()["status"] == "pending"
    assert await active_membership(former["id"], venues["a"]) is None


@pytest.mark.parametrize("route", ROUTES)
async def test_active_staff_cannot_be_reinvited(client, venues, route):
    owner = await _owner_at(venues["a"])
    member = await make_user(email="member@example.com")
    await add_staff(member["id"], venues["a"], "staff")

    resp = await invite(client, route, venues["a"], owner, member["email"])

    assert resp.status_code == 409, resp.text
    assert await invitations_for() == []


@pytest.mark.parametrize("route", ROUTES)
async def test_only_the_invited_user_can_accept(client, venues, route):
    owner = await _owner_at(venues["a"])
    await make_user(email="intended@example.com")
    someone_else = await make_user(email="someone.else@example.com")

    resp = await invite(client, route, venues["a"], owner, "intended@example.com")
    code = resp.json()["invitation_code"]

    accept = await client.post(
        "/me/bars/accept-invitation",
        json={"invitation_code": code},
        headers=headers_for(someone_else),
    )

    assert accept.status_code == 403, accept.text
    assert (await invitations_for())[0]["status"] == "pending"
    assert await active_membership(someone_else["id"], venues["a"]) is None


@pytest.mark.parametrize("route", ROUTES)
async def test_inviter_cannot_accept_on_behalf_of_invitee(client, venues, route):
    owner = await _owner_at(venues["a"])

    resp = await invite(client, route, venues["a"], owner, "absent@example.com", role="admin")
    code = resp.json()["invitation_code"]

    accept = await client.post(
        "/me/bars/accept-invitation",
        json={"invitation_code": code},
        headers=headers_for(owner),
    )

    assert accept.status_code == 403, accept.text
    assert (await invitations_for())[0]["status"] == "pending"


@pytest.mark.parametrize("route", ROUTES)
async def test_expired_invitation_cannot_be_accepted(client, venues, route):
    owner = await _owner_at(venues["a"])
    invitee = await make_user(email="late@example.com")

    resp = await invite(client, route, venues["a"], owner, invitee["email"])
    code = resp.json()["invitation_code"]

    # Move past the 7-day window.
    await test_database.execute(
        StaffInvitation.__table__.update()
        .where(StaffInvitation.invitation_code == code)
        .values(expires_at=datetime.utcnow() - timedelta(seconds=1))
    )

    pending = await client.get("/me/bars/invitations/pending", headers=headers_for(invitee))
    assert pending.status_code == 200
    assert pending.json() == []

    accept = await client.post(
        "/me/bars/accept-invitation",
        json={"invitation_code": code},
        headers=headers_for(invitee),
    )

    assert accept.status_code == 410, accept.text
    row = (await invitations_for())[0]
    assert row["status"] != "accepted"
    assert row["accepted_by_user_id"] is None
    assert await active_membership(invitee["id"], venues["a"]) is None


@pytest.mark.parametrize("route", ROUTES)
async def test_invitation_acceptable_just_before_expiry(client, venues, route):
    owner = await _owner_at(venues["a"])
    invitee = await make_user(email="ontime@example.com")

    resp = await invite(client, route, venues["a"], owner, invitee["email"])
    code = resp.json()["invitation_code"]

    # Day 7, one minute before expiry: still pending and still acceptable.
    await test_database.execute(
        StaffInvitation.__table__.update()
        .where(StaffInvitation.invitation_code == code)
        .values(expires_at=datetime.utcnow() + timedelta(minutes=1))
    )
    assert (await invitations_for())[0]["status"] == "pending"

    accept = await client.post(
        "/me/bars/accept-invitation",
        json={"invitation_code": code},
        headers=headers_for(invitee),
    )

    assert accept.status_code == 200, accept.text
    assert await active_membership(invitee["id"], venues["a"]) is not None


# ---------------------------------------------------------------------------
# Shared validation (identical on both routes)
# ---------------------------------------------------------------------------

@pytest.mark.parametrize("route", ROUTES)
async def test_invalid_role_is_rejected(client, venues, route):
    owner = await _owner_at(venues["a"])

    resp = await invite(client, route, venues["a"], owner, "x@example.com", role="superuser")

    assert resp.status_code == 400, resp.text
    assert await invitations_for() == []


@pytest.mark.parametrize("route", ROUTES)
async def test_empty_contact_is_rejected(client, venues, route):
    owner = await _owner_at(venues["a"])

    resp = await invite(client, route, venues["a"], owner, "")

    assert resp.status_code == 400, resp.text
    assert await invitations_for() == []


async def test_service_fails_closed_without_staff_manage(client, venues):
    """create_staff_invitation re-checks staff:manage, so a future caller that
    skips authorization cannot create invitations."""
    from fastapi import HTTPException
    from app.auth.rbac_middleware import AuthUser, BarAuthContext
    from app.bars_and_restaurants.services.staff_invitations import create_staff_invitation

    user = await make_user()
    auth = BarAuthContext(
        user=AuthUser(id=user["id"], email=user["email"], phone_number=user["phone"],
                      is_active=True, user_type="business"),
        bar_id=venues["a"],
        role="manager",
        permissions=["staff:view"],
    )

    with pytest.raises(HTTPException) as exc:
        await create_staff_invitation(auth, "x@example.com", "staff")

    assert exc.value.status_code == 403
    assert await invitations_for() == []


# ---------------------------------------------------------------------------
# Role hierarchy: nobody can invite above their own role
#   owner   -> owner, admin, manager, cashier, staff
#   admin   ->        admin, manager, cashier, staff
#   manager ->               manager, cashier, staff   (needs a staff:manage grant)
#   cashier ->                        cashier, staff   (needs a staff:manage grant)
#   staff   ->                                 staff   (needs a staff:manage grant)
# ---------------------------------------------------------------------------

HIERARCHY = ["owner", "admin", "manager", "cashier", "staff"]  # highest first
ALLOWED_INVITES = {
    inviter: set(HIERARCHY[HIERARCHY.index(inviter):]) for inviter in HIERARCHY
}


async def _inviter_with_role(bar_id, role):
    """An inviter holding staff:manage at ``bar_id`` with the given role.
    Owner and admin have it by default; lower roles get a custom grant."""
    user = await make_user()
    grant = None if role in ("owner", "admin") else ["staff:manage"]
    await add_staff(user["id"], bar_id, role, custom_permissions=grant)
    return user


def test_allowed_invites_table_matches_the_requested_policy():
    """Pin the expected policy explicitly, independent of the code under test."""
    assert ALLOWED_INVITES == {
        "owner": {"owner", "admin", "manager", "cashier", "staff"},
        "admin": {"admin", "manager", "cashier", "staff"},
        "manager": {"manager", "cashier", "staff"},
        "cashier": {"cashier", "staff"},
        "staff": {"staff"},
    }


@pytest.mark.parametrize("route", ROUTES)
@pytest.mark.parametrize("inviter_role", HIERARCHY)
@pytest.mark.parametrize("target_role", HIERARCHY)
async def test_role_hierarchy_matrix(client, venues, route, inviter_role, target_role):
    inviter = await _inviter_with_role(venues["a"], inviter_role)

    resp = await invite(
        client, route, venues["a"], inviter,
        f"{inviter_role}.invites.{target_role}@example.com", role=target_role,
    )

    if target_role in ALLOWED_INVITES[inviter_role]:
        assert resp.status_code == 200, resp.text
        assert resp.json()["role"] == target_role
        assert resp.json()["status"] == "pending"
        assert len(await invitations_for(venues["a"])) == 1
    else:
        assert resp.status_code == 403, resp.text
        assert resp.json()["detail"] == (
            f"Cannot invite a {target_role}: role is above your own ({inviter_role})"
        )
        assert await invitations_for() == []


@pytest.mark.parametrize("route", ROUTES)
@pytest.mark.parametrize("target_role", ["admin", "manager"])
async def test_cashier_cannot_invite_own_alt_account_above_cashier(client, venues, route, target_role):
    """The escalation this rule exists for: a cashier with staff:manage
    inviting a second account of their own into a higher role."""
    cashier = await make_user(email="cashier@example.com")
    await add_staff(cashier["id"], venues["a"], "cashier", custom_permissions=["staff:manage"])
    alt = await make_user(email="cashier.alt@example.com")

    resp = await invite(client, route, venues["a"], cashier, alt["email"], role=target_role)

    assert resp.status_code == 403, resp.text
    assert await invitations_for() == []
    assert await active_membership(alt["id"], venues["a"]) is None


@pytest.mark.parametrize("route", ROUTES)
async def test_hierarchy_uses_role_at_the_target_venue(client, venues, route):
    # Owner at A, cashier (with grant) at B: at B they rank as a cashier.
    user = await make_user()
    await add_staff(user["id"], venues["a"], "owner")
    await add_staff(user["id"], venues["b"], "cashier", custom_permissions=["staff:manage"])

    above = await invite(client, route, venues["b"], user, "b.manager@example.com", role="manager")
    same = await invite(client, route, venues["b"], user, "b.cashier@example.com", role="cashier")

    assert above.status_code == 403, above.text
    assert same.status_code == 200, same.text
    assert [r["role"] for r in await invitations_for(venues["b"])] == ["cashier"]


@pytest.mark.parametrize("route", ROUTES)
async def test_unknown_inviter_role_cannot_invite_anyone(client, venues, route):
    # A legacy/unknown role with a staff:manage grant ranks below every role.
    inviter = await make_user()
    await add_staff(inviter["id"], venues["a"], "legacy_role", custom_permissions=["staff:manage"])

    resp = await invite(client, route, venues["a"], inviter, "x@example.com", role="staff")

    assert resp.status_code == 403, resp.text
    assert await invitations_for() == []


# ---------------------------------------------------------------------------
# Existing-member check (same matching rules as invitation acceptance)
# ---------------------------------------------------------------------------

@pytest.mark.parametrize("route", ROUTES)
@pytest.mark.parametrize("contact", [
    "Member@Example.COM",
    "  member@example.com  ",
    "+5511912345678",
    "+55 (11) 91234-5678",
    " +55 11 91234 5678 ",
])
async def test_active_member_detected_regardless_of_formatting(client, venues, route, contact):
    owner = await _owner_at(venues["a"])
    member = await make_user(email="member@example.com", phone="+5511912345678")
    await add_staff(member["id"], venues["a"], "staff")

    resp = await invite(client, route, venues["a"], owner, contact, role="admin")

    assert resp.status_code == 409, resp.text
    assert await invitations_for() == []


@pytest.mark.parametrize("route", ROUTES)
async def test_member_of_other_venue_can_be_invited(client, venues, route):
    owner = await _owner_at(venues["a"])
    other = await make_user(email="elsewhere@example.com")
    await add_staff(other["id"], venues["b"], "admin")

    resp = await invite(client, route, venues["a"], owner, "Elsewhere@example.com")

    assert resp.status_code == 200, resp.text
    assert await active_membership(other["id"], venues["a"]) is None


@pytest.mark.parametrize("route", ROUTES)
async def test_members_without_phone_do_not_match_phone_invites(client, venues, route):
    owner = await _owner_at(venues["a"])
    phoneless = await make_user(email="phoneless@example.com", no_phone=True)
    await add_staff(phoneless["id"], venues["a"], "staff")

    resp = await invite(client, route, venues["a"], owner, "+5511900000001")

    assert resp.status_code == 200, resp.text


# ---------------------------------------------------------------------------
# Contact validation: classify first ("@" -> email, phone-shaped -> phone,
# anything else -> neither), then validate; malformed contacts are rejected
# before anything is stored; valid ones are stored in canonical form
# ---------------------------------------------------------------------------

NOT_A_CONTACT = "Valid email or phone required"
BAD_EMAIL = "Invalid email address"
BAD_PHONE = "Invalid phone number. Use international format, e.g. +5531999999999"

# Contain "@": always treated as an email, even when malformed.
MALFORMED_EMAILS = [
    "john@",
    "@example.com",
    "john@@example.com",
    "john@example",
    "john doe@example.com",
    "john@exa mple.com",
    "john@.example.com",
    "john..doe@example.com",
    "john@example..com",
    "<script>@example.com",
    "john@example.com@example.com",
    "@",
    "a@b",
    "+5511912345678@",            # phone-looking, but "@" makes it an email
    "55 11 @ 91234",
    "hello @ world",
]

# No "@" and not phone-shaped: neither an email nor a phone.
ARBITRARY_TEXT = [
    "",
    "   ",
    "hello",
    "not a contact",
    "john.doe.example.com",
    "call me maybe",
    "DROP TABLE staff_invitations;",
    "null",
    "🍺🍺🍺",
    "12 Main Street",             # digits, but letters too
    "1-800-FLOWERS",              # vanity number
    "tel:+5511912345678",
    "+55 11 91234-5678 ext 9",
    "+55119123456O8",             # letter O instead of zero
    "+5511912345678#",
    "+55/11/912345678",
    "---",                        # punctuation only, no digit
    "+",
    "( )",
    "+5٥١١٩١٢٣٤٥٦٧٨",             # Arabic-Indic digits
    "+5５１１９１２３４５６７８",      # full-width digits
]

# Phone-shaped (digits and + space - ( ) . only) but not valid E.164.
MALFORMED_PHONES = [
    "5511912345678",              # missing "+country code"
    "11 91234-5678",              # local format, no country code
    "+0123456789",                # country code cannot start with 0
    "++5511912345678",
    "+55 11 9",                   # too short (5 digits)
    "+1234567",                   # 7 digits, below E.164 minimum
    "+1234567890123456",          # 16 digits, above E.164 maximum
    "+55.11.91234.5678",          # dots are not accepted formatting
    "55+11912345678",             # "+" not at the start
    "0",
]

CONTACT_CASES = (
    [(c, BAD_EMAIL) for c in MALFORMED_EMAILS]
    + [(c, NOT_A_CONTACT) for c in ARBITRARY_TEXT]
    + [(c, BAD_PHONE) for c in MALFORMED_PHONES]
)


@pytest.mark.parametrize("value, kind", (
    [(c, "email") for c in MALFORMED_EMAILS]
    + [(c, None) for c in ARBITRARY_TEXT]
    + [(c, "phone") for c in MALFORMED_PHONES]
    + [
        ("new.hire@example.com", "email"),
        ("  New.Hire@Example.COM ", "email"),
        ("+5511912345678", "phone"),
        ("+55 (11) 91234-5678", "phone"),
        (" +1 415 555 0100 ", "phone"),
        (None, None),
    ]
))
def test_classify_contact(value, kind):
    from app.auth.contact_validation import classify_contact

    assert classify_contact(value) == kind


@pytest.mark.parametrize("value", ARBITRARY_TEXT)
def test_text_without_at_that_is_not_phone_shaped_is_never_a_phone(value):
    from fastapi import HTTPException
    from app.bars_and_restaurants.services.staff_invitations import parse_invitation_contact

    with pytest.raises(HTTPException) as exc:
        parse_invitation_contact(value)

    assert exc.value.status_code == 400
    assert exc.value.detail == NOT_A_CONTACT


@pytest.mark.parametrize("value", ["+5٥١١٩١٢٣٤٥٦٧٨", "+5５１１９１２３４５６７８", "+55119１２３４５６７８"])
def test_phone_validation_accepts_ascii_digits_only(value):
    """Non-ASCII digits are rejected by the shared phone rule itself (used by
    invitations and by account contact changes), not only by classification."""
    from app.auth.contact_validation import InvalidContact, canonical_phone
    from app.auth.contact_change import normalize_contact
    from app.errors import APIError

    with pytest.raises(InvalidContact):
        canonical_phone(value)
    with pytest.raises(APIError):
        normalize_contact("phone", value)


@pytest.mark.parametrize("route", ROUTES)
@pytest.mark.parametrize("contact, expected_detail", CONTACT_CASES)
async def test_malformed_contact_is_rejected_and_nothing_stored(
    client, venues, route, contact, expected_detail, monkeypatch
):
    from app.bars_and_restaurants.services import staff_invitations as svc

    async def must_not_run(*args, **kwargs):
        raise AssertionError("contact must be validated before any lookup or write")

    monkeypatch.setattr(svc, "ensure_not_active_member", must_not_run)
    monkeypatch.setattr(svc, "persist_staff_invitation", must_not_run)
    owner = await _owner_at(venues["a"])

    resp = await invite(client, route, venues["a"], owner, contact)

    assert resp.status_code == 400, resp.text
    assert resp.json()["detail"] == expected_detail
    assert await invitations_for() == []


@pytest.mark.parametrize("route", ROUTES)
@pytest.mark.parametrize("contact, stored_email, stored_phone", [
    ("new.hire@example.com", "new.hire@example.com", None),
    ("  New.Hire@Example.COM  ", "new.hire@example.com", None),
    ("user+tag@sub.example.co", "user+tag@sub.example.co", None),
    ("+5511912345678", None, "+5511912345678"),
    ("+55 (11) 91234-5678", None, "+5511912345678"),
    ("  +1 415 555 0100 ", None, "+14155550100"),
])
async def test_valid_contact_is_stored_canonical(
    client, venues, route, contact, stored_email, stored_phone
):
    owner = await _owner_at(venues["a"])

    resp = await invite(client, route, venues["a"], owner, contact)

    assert resp.status_code == 200, resp.text
    assert resp.json()["email"] == stored_email
    assert resp.json()["phone"] == stored_phone
    row = (await invitations_for())[0]
    assert row["email"] == stored_email
    assert row["phone"] == stored_phone


@pytest.mark.parametrize("route", ROUTES)
async def test_formatted_phone_invite_is_accepted_by_the_account_owner(client, venues, route):
    """A canonicalized phone invitation matches the account whose (E.164)
    phone was formatted differently when the inviter typed it."""
    owner = await _owner_at(venues["a"])
    invitee = await make_user(phone="+5521998765432", phone_verified=True)

    resp = await invite(client, route, venues["a"], owner, "+55 (21) 99876-5432", role="cashier")
    assert resp.status_code == 200, resp.text
    assert resp.json()["phone"] == "+5521998765432"

    accept = await client.post(
        "/me/bars/accept-invitation",
        json={"invitation_code": resp.json()["invitation_code"]},
        headers=headers_for(invitee),
    )
    assert accept.status_code == 200, accept.text
    assert (await active_membership(invitee["id"], venues["a"]))["role"] == "cashier"


def test_invite_and_account_contacts_share_the_same_rules():
    """Invitation contacts and account contacts (contact change) are validated
    by the same functions, so they cannot drift apart."""
    from app.auth import contact_change
    from app.auth.contact_validation import canonical_email, canonical_phone
    from app.bars_and_restaurants.services import staff_invitations as svc

    assert svc.canonical_email is canonical_email is contact_change.canonical_email
    assert svc.canonical_phone is canonical_phone is contact_change.canonical_phone


# ---------------------------------------------------------------------------
# Delegation: both routes run every step through the one service
# ---------------------------------------------------------------------------

STEPS_NEW_INVITATION = [
    "parse_invitation_contact",
    "parse_invitation_role",
    "ensure_can_invite_role",
    "lock_bar_invitations",
    "ensure_not_active_member",
    "resolve_pending_invitations",
    "generate_invitation_code",
    "persist_staff_invitation",
]
# A resend reuses the pending invitation: no new code, no insert.
STEPS_RESEND = STEPS_NEW_INVITATION[:-2]


def _spy_on_service(monkeypatch):
    import inspect
    from app.bars_and_restaurants.services import staff_invitations as svc

    calls = []

    def spy(name):
        original = getattr(svc, name)
        if inspect.iscoroutinefunction(original):
            async def wrapper(*args, **kwargs):
                calls.append((name, args))
                return await original(*args, **kwargs)
        else:
            def wrapper(*args, **kwargs):
                calls.append((name, args))
                return original(*args, **kwargs)
        monkeypatch.setattr(svc, name, wrapper)

    for name in STEPS_NEW_INVITATION:
        spy(name)
    return calls


@pytest.mark.parametrize("route", ROUTES)
async def test_routes_delegate_every_step_to_the_service(client, venues, route, monkeypatch):
    calls = _spy_on_service(monkeypatch)

    owner = await _owner_at(venues["a"])
    resp = await invite(client, route, venues["a"], owner, "delegate@example.com", role="manager")

    assert resp.status_code == 200, resp.text
    assert [name for name, _ in calls] == STEPS_NEW_INVITATION
    args = dict(calls)
    assert args["parse_invitation_contact"] == ("delegate@example.com",)
    assert args["parse_invitation_role"] == ("manager",)
    assert args["lock_bar_invitations"] == (venues["a"],)
    assert args["ensure_not_active_member"] == (venues["a"], "delegate@example.com", None)
    assert args["persist_staff_invitation"][0]["bar_id"] == venues["a"]


@pytest.mark.parametrize("route", ROUTES)
async def test_resend_is_delegated_to_the_service_too(client, venues, route, monkeypatch):
    owner = await _owner_at(venues["a"])
    first = await invite(client, route, venues["a"], owner, "resend.delegate@example.com")
    assert first.status_code == 200, first.text

    calls = _spy_on_service(monkeypatch)
    again = await invite(client, route, venues["a"], owner, "resend.delegate@example.com")

    assert again.status_code == 200, again.text
    assert [name for name, _ in calls] == STEPS_RESEND


@pytest.mark.parametrize("route", ROUTES)
async def test_invitee_receives_the_service_generated_code(client, venues, route, monkeypatch):
    from app.bars_and_restaurants.services import staff_invitations as svc

    pinned = f"pinned-code-{route}"
    monkeypatch.setattr(svc, "generate_invitation_code", lambda: pinned)

    owner = await _owner_at(venues["a"])
    invitee = await make_user(email=f"pin.{route}@example.com")

    resp = await invite(client, route, venues["a"], owner, invitee["email"])

    assert resp.status_code == 200, resp.text
    assert resp.json()["invitation_code"] == pinned
    assert (await invitations_for())[0]["invitation_code"] == pinned

    pending = await client.get("/me/bars/invitations/pending", headers=headers_for(invitee))
    assert [p["invitation_code"] for p in pending.json()] == [pinned]

    accept = await client.post(
        "/me/bars/accept-invitation", json={"invitation_code": pinned}, headers=headers_for(invitee),
    )
    assert accept.status_code == 200, accept.text


@pytest.mark.parametrize("route", ROUTES)
async def test_generated_codes_are_unique(client, venues, route):
    owner = await _owner_at(venues["a"])

    codes = set()
    for i in range(5):
        resp = await invite(client, route, venues["a"], owner, f"unique{i}@example.com")
        assert resp.status_code == 200, resp.text
        codes.add(resp.json()["invitation_code"])

    assert len(codes) == 5
    assert {r["invitation_code"] for r in await invitations_for()} == codes


# ---------------------------------------------------------------------------
# Persistence: one writer, and the response is exactly what was stored
# ---------------------------------------------------------------------------

def test_only_the_service_writes_staff_invitations():
    """Guard: no other module may insert invitations or mint invitation codes."""
    import re
    from pathlib import Path

    app_dir = Path(__file__).resolve().parent.parent / "app"
    service = app_dir / "bars_and_restaurants" / "services" / "staff_invitations.py"
    writers = re.compile(
        r"StaffInvitation\.__table__\.insert\(|(?<!class )StaffInvitation\(|insert\s+into\s+staff_invitations",
        re.IGNORECASE,
    )
    offenders = [
        str(path.relative_to(app_dir))
        for path in app_dir.rglob("*.py")
        if path != service and writers.search(path.read_text())
    ]
    assert offenders == []

    routes_dir = app_dir / "bars_and_restaurants" / "routes"
    for route_file in ("staff.py", "staff_invite.py"):
        source = (routes_dir / route_file).read_text()
        assert "token_urlsafe" not in source and "import secrets" not in source, route_file


@pytest.mark.parametrize("route", ROUTES)
async def test_response_is_the_persisted_row(client, venues, route):
    owner = await _owner_at(venues["a"])

    resp = await invite(client, route, venues["a"], owner, "+5511955554444", role="cashier")

    assert resp.status_code == 200, resp.text
    body = resp.json()
    row = (await invitations_for())[0]
    assert body["id"] == row["id"]
    assert body["bar_id"] == row["bar_id"]
    assert body["email"] == row["email"]
    assert body["phone"] == row["phone"]
    assert body["role"] == row["role"]
    assert body["status"] == row["status"] == "pending"
    assert body["invitation_code"] == row["invitation_code"]
    assert datetime.fromisoformat(body["expires_at"]).replace(tzinfo=None) == row["expires_at"]


@pytest.mark.parametrize("route", ROUTES)
async def test_duplicate_code_persists_nothing(client, venues, route, monkeypatch):
    """If the insert fails (e.g. a code collision), no invitation is stored
    and no code is handed out."""
    from app.bars_and_restaurants.services import staff_invitations as svc

    owner = await _owner_at(venues["a"])
    monkeypatch.setattr(svc, "generate_invitation_code", lambda: "same-code")
    first = await invite(client, route, venues["a"], owner, "first@example.com")
    assert first.status_code == 200, first.text

    second = await invite(client, route, venues["a"], owner, "second@example.com")

    assert second.status_code == 500, second.text
    assert second.json() == {
        "error_code": "UNKNOWN", "message": "Could not create the invitation",
    }

    rows = await invitations_for()
    assert [r["email"] for r in rows] == ["first@example.com"]


@pytest.mark.parametrize("route", ROUTES)
async def test_failed_read_back_rolls_back_the_insert(client, venues, route, monkeypatch):
    """Insert and read-back are one transaction: if the stored row cannot be
    read back, the insert is rolled back rather than leaving an invitation
    whose code was never returned."""
    from app.bars_and_restaurants.services import staff_invitations as svc

    real_db = svc.database

    class ReadBackFails:
        def __getattr__(self, name):
            return getattr(real_db, name)

        async def fetch_one(self, query, *args, **kwargs):
            if "staff_invitations" in str(query):
                return None
            return await real_db.fetch_one(query, *args, **kwargs)

    monkeypatch.setattr(svc, "database", ReadBackFails())
    owner = await _owner_at(venues["a"])

    resp = await invite(client, route, venues["a"], owner, "rollback@example.com")
    assert resp.status_code == 500, resp.text

    monkeypatch.setattr(svc, "database", real_db)
    assert await invitations_for() == []


# ---------------------------------------------------------------------------
# Role changes (PUT /bars/{bar_id}/staff/{staff_id}/role) follow the same
# rank rule: nobody can assign a role above their own, or change the role of
# someone ranked above them, and that includes their own membership.
# ---------------------------------------------------------------------------

async def change_role(client, actor, bar_id, staff_id, role):
    return await client.put(
        f"/bars/{bar_id}/staff/{staff_id}/role",
        json={"role": role},
        headers=headers_for(actor),
    )


async def _member_with_role(bar_id, role):
    """(user, staff_id) holding staff:manage (custom grant below admin)."""
    user = await make_user()
    grant = None if role in ("owner", "admin") else ["staff:manage"]
    staff_id = await add_staff(user["id"], bar_id, role, custom_permissions=grant)
    return user, staff_id


async def role_of(staff_id):
    row = await test_database.fetch_one(
        BarStaff.__table__.select().where(BarStaff.id == staff_id)
    )
    return row["role"]


@pytest.mark.parametrize("target", ["admin", "manager", "owner"])
async def test_cashier_cannot_promote_themselves(client, venues, target):
    cashier, staff_id = await _member_with_role(venues["a"], "cashier")

    resp = await change_role(client, cashier, venues["a"], staff_id, target)

    assert resp.status_code == 403, resp.text
    assert await role_of(staff_id) == "cashier"
    my_bars = await client.get("/me/bars", headers=headers_for(cashier))
    assert [(b["bar_id"], b["role"]) for b in my_bars.json()] == [(venues["a"], "cashier")]


@pytest.mark.parametrize("actor, target", [
    ("staff", "cashier"),
    ("staff", "admin"),
    ("manager", "admin"),
    ("manager", "owner"),
    ("admin", "owner"),
])
async def test_nobody_can_promote_themselves_above_their_role(client, venues, actor, target):
    user, staff_id = await _member_with_role(venues["a"], actor)

    resp = await change_role(client, user, venues["a"], staff_id, target)

    assert resp.status_code == 403, resp.text
    assert await role_of(staff_id) == actor


@pytest.mark.parametrize("actor, target", [
    ("cashier", "cashier"),
    ("cashier", "staff"),
    ("admin", "manager"),
])
async def test_self_change_within_rank_is_allowed(client, venues, actor, target):
    user, staff_id = await _member_with_role(venues["a"], actor)

    resp = await change_role(client, user, venues["a"], staff_id, target)

    assert resp.status_code == 200, resp.text
    assert await role_of(staff_id) == target


async def test_self_promotion_blocked_even_when_owner_elsewhere(client, venues):
    user = await make_user()
    await add_staff(user["id"], venues["a"], "owner")
    staff_b = await add_staff(user["id"], venues["b"], "cashier", custom_permissions=["staff:manage"])

    resp = await change_role(client, user, venues["b"], staff_b, "admin")

    assert resp.status_code == 403, resp.text
    assert await role_of(staff_b) == "cashier"


@pytest.mark.parametrize("actor_role", HIERARCHY)
@pytest.mark.parametrize("new_role", HIERARCHY)
async def test_role_change_matrix_new_role(client, venues, actor_role, new_role):
    """Changing a plain staff member's role: allowed iff new_role <= actor."""
    actor, _ = await _member_with_role(venues["a"], actor_role)
    member = await make_user()
    member_staff_id = await add_staff(member["id"], venues["a"], "staff")

    resp = await change_role(client, actor, venues["a"], member_staff_id, new_role)

    if new_role in ALLOWED_INVITES[actor_role]:
        assert resp.status_code == 200, resp.text
        assert await role_of(member_staff_id) == new_role
    else:
        assert resp.status_code == 403, resp.text
        assert await role_of(member_staff_id) == "staff"


@pytest.mark.parametrize("actor_role", HIERARCHY)
@pytest.mark.parametrize("target_role", HIERARCHY)
async def test_role_change_matrix_target_rank(client, venues, actor_role, target_role):
    """Demoting someone to staff: allowed iff their current role <= actor."""
    actor, _ = await _member_with_role(venues["a"], actor_role)
    member = await make_user()
    member_staff_id = await add_staff(member["id"], venues["a"], target_role)

    resp = await change_role(client, actor, venues["a"], member_staff_id, "staff")

    if target_role in ALLOWED_INVITES[actor_role]:
        assert resp.status_code == 200, resp.text
        assert await role_of(member_staff_id) == "staff"
    else:
        assert resp.status_code == 403, resp.text
        assert await role_of(member_staff_id) == target_role


# ---------------------------------------------------------------------------
# Duplicate / resend policy: at most one live pending invitation per venue
# and contact. Same role -> resend (same code, renewed expiry); different
# role -> old revoked, new one created; old one ranked above caller -> 409.
# ---------------------------------------------------------------------------

async def live_pending(bar_id=None):
    now = datetime.utcnow()
    return [
        r for r in await invitations_for(bar_id)
        if r["status"] == "pending" and r["expires_at"] > now
    ]


async def insert_invitation(bar_id, *, email=None, phone=None, role="staff", code=None,
                            status="pending", expires_in=timedelta(days=7), invited_by_id=None):
    """Insert a row directly (legacy data, other inviters, expired rows...)."""
    code = code or f"legacy-{_next()}"
    inv_id = await test_database.execute(StaffInvitation.__table__.insert().values(
        bar_id=bar_id, email=email, phone=phone, role=role, invitation_code=code,
        status=status, expires_at=datetime.utcnow() + expires_in, invited_by_id=invited_by_id,
    ))
    return inv_id, code


async def invitation_by_id(inv_id):
    return await test_database.fetch_one(
        StaffInvitation.__table__.select().where(StaffInvitation.id == inv_id)
    )


@pytest.mark.parametrize("first_route", ROUTES)
@pytest.mark.parametrize("second_route", ROUTES)
async def test_reinvite_same_role_resends_the_same_invitation(
    client, venues, first_route, second_route
):
    owner = await _owner_at(venues["a"])
    first = await invite(client, first_route, venues["a"], owner, "again@example.com", role="cashier")
    assert first.status_code == 200, first.text

    # Age the invitation by 3 days so the renewal is observable.
    await test_database.execute(
        StaffInvitation.__table__.update()
        .where(StaffInvitation.id == first.json()["id"])
        .values(expires_at=datetime.utcnow() + timedelta(days=4))
    )

    before = datetime.utcnow()
    second = await invite(client, second_route, venues["a"], owner, "again@example.com", role="cashier")

    assert second.status_code == 200, second.text
    assert second.json()["id"] == first.json()["id"]
    assert second.json()["invitation_code"] == first.json()["invitation_code"]
    assert second.json()["status"] == "pending"
    assert set(second.json()) == set(first.json())  # same response shape
    rows = await invitations_for()
    assert len(rows) == 1
    assert rows[0]["expires_at"] >= before + timedelta(days=7) - timedelta(seconds=1)


@pytest.mark.parametrize("route", ROUTES)
@pytest.mark.parametrize("first, again", [
    ("member.x@example.com", "  Member.X@EXAMPLE.com "),
    ("+5511912340000", "+55 (11) 91234-0000"),
])
async def test_resend_matches_differently_formatted_contact(client, venues, route, first, again):
    owner = await _owner_at(venues["a"])
    r1 = await invite(client, route, venues["a"], owner, first)
    r2 = await invite(client, route, venues["a"], owner, again)

    assert r1.status_code == r2.status_code == 200, (r1.text, r2.text)
    assert r2.json()["invitation_code"] == r1.json()["invitation_code"]
    assert len(await invitations_for()) == 1


@pytest.mark.parametrize("route", ROUTES)
@pytest.mark.parametrize("legacy_email, legacy_phone, contact", [
    ("Legacy.User@Example.COM ", None, "legacy.user@example.com"),
    (None, "+55 11 91234-9999", "+5511912349999"),
])
async def test_resend_matches_legacy_non_canonical_rows(
    client, venues, route, legacy_email, legacy_phone, contact
):
    owner = await _owner_at(venues["a"])
    inv_id, code = await insert_invitation(
        venues["a"], email=legacy_email, phone=legacy_phone, invited_by_id=owner["id"],
    )

    resp = await invite(client, route, venues["a"], owner, contact)

    assert resp.status_code == 200, resp.text
    assert resp.json()["id"] == inv_id
    assert resp.json()["invitation_code"] == code
    assert len(await invitations_for()) == 1


@pytest.mark.parametrize("route", ROUTES)
async def test_resend_by_another_inviter_keeps_the_original_inviter(client, venues, route):
    owner = await _owner_at(venues["a"])
    admin, _ = await _member_with_role(venues["a"], "admin")
    first = await invite(client, route, venues["a"], owner, "shared@example.com", role="manager")

    again = await invite(client, route, venues["a"], admin, "shared@example.com", role="manager")

    assert again.status_code == 200, again.text
    assert again.json()["invitation_code"] == first.json()["invitation_code"]
    assert (await invitations_for())[0]["invited_by_id"] == owner["id"]


@pytest.mark.parametrize("route", ROUTES)
async def test_resent_invitation_is_still_only_pending_and_accepts_once(client, venues, route):
    owner = await _owner_at(venues["a"])
    invitee = await make_user(email="resent.invitee@example.com")
    first = await invite(client, route, venues["a"], owner, invitee["email"])
    await invite(client, route, venues["a"], owner, invitee["email"])

    assert await active_membership(invitee["id"], venues["a"]) is None
    accept = await client.post(
        "/me/bars/accept-invitation",
        json={"invitation_code": first.json()["invitation_code"]},
        headers=headers_for(invitee),
    )
    assert accept.status_code == 200, accept.text

    # Now a member: a third invite is a 409, not a new invitation.
    third = await invite(client, route, venues["a"], owner, invitee["email"])
    assert third.status_code == 409, third.text
    assert len(await invitations_for()) == 1


@pytest.mark.parametrize("route", ROUTES)
async def test_reinvite_with_different_role_replaces_the_invitation(client, venues, route):
    owner = await _owner_at(venues["a"])
    invitee = await make_user(email="role.change@example.com")
    old = await invite(client, route, venues["a"], owner, invitee["email"], role="staff")

    new = await invite(client, route, venues["a"], owner, invitee["email"], role="manager")

    assert new.status_code == 200, new.text
    assert new.json()["role"] == "manager"
    assert new.json()["invitation_code"] != old.json()["invitation_code"]
    assert (await invitation_by_id(old.json()["id"]))["status"] == "revoked"
    assert [r["id"] for r in await live_pending()] == [new.json()["id"]]

    old_accept = await client.post(
        "/me/bars/accept-invitation",
        json={"invitation_code": old.json()["invitation_code"]},
        headers=headers_for(invitee),
    )
    assert old_accept.status_code == 410, old_accept.text
    assert await active_membership(invitee["id"], venues["a"]) is None

    new_accept = await client.post(
        "/me/bars/accept-invitation",
        json={"invitation_code": new.json()["invitation_code"]},
        headers=headers_for(invitee),
    )
    assert new_accept.status_code == 200, new_accept.text
    assert (await active_membership(invitee["id"], venues["a"]))["role"] == "manager"


@pytest.mark.parametrize("route", ROUTES)
@pytest.mark.parametrize("actor_role, pending_role, new_role", [
    ("cashier", "admin", "staff"),     # owner's admin invite, cashier re-invites as staff
    ("cashier", "manager", "cashier"),
    ("admin", "owner", "admin"),
    ("manager", "admin", "manager"),
])
async def test_cannot_override_a_pending_invitation_ranked_above_you(
    client, venues, route, actor_role, pending_role, new_role
):
    owner = await _owner_at(venues["a"])
    actor, _ = await _member_with_role(venues["a"], actor_role)
    inv_id, code = await insert_invitation(
        venues["a"], email="vip@example.com", role=pending_role, invited_by_id=owner["id"],
    )
    before = await invitation_by_id(inv_id)

    resp = await invite(client, route, venues["a"], actor, "vip@example.com", role=new_role)

    assert resp.status_code == 409, resp.text
    assert resp.json() == {"detail": "A pending invitation for this contact already exists"}
    after = await invitation_by_id(inv_id)
    assert (after["status"], after["expires_at"], after["role"]) == (
        "pending", before["expires_at"], pending_role,
    )
    assert len(await invitations_for()) == 1


@pytest.mark.parametrize("route", ROUTES)
async def test_expired_pending_invitation_is_marked_expired_and_replaced(client, venues, route):
    owner = await _owner_at(venues["a"])
    invitee = await make_user(email="expired.again@example.com")
    old_id, old_code = await insert_invitation(
        venues["a"], email=invitee["email"], expires_in=-timedelta(minutes=1),
    )

    resp = await invite(client, route, venues["a"], owner, invitee["email"])

    assert resp.status_code == 200, resp.text
    assert resp.json()["id"] != old_id
    assert resp.json()["invitation_code"] != old_code
    assert (await invitation_by_id(old_id))["status"] == "expired"
    assert [r["id"] for r in await live_pending()] == [resp.json()["id"]]

    old_accept = await client.post(
        "/me/bars/accept-invitation", json={"invitation_code": old_code}, headers=headers_for(invitee),
    )
    assert old_accept.status_code == 410, old_accept.text


@pytest.mark.parametrize("route", ROUTES)
@pytest.mark.parametrize("status", ["accepted", "revoked", "expired"])
async def test_closed_invitations_do_not_block_a_new_one(client, venues, route, status):
    owner = await _owner_at(venues["a"])
    old_id, old_code = await insert_invitation(venues["a"], email="closed@example.com", status=status)

    resp = await invite(client, route, venues["a"], owner, "closed@example.com")

    assert resp.status_code == 200, resp.text
    assert resp.json()["invitation_code"] != old_code
    assert (await invitation_by_id(old_id))["status"] == status  # untouched


@pytest.mark.parametrize("route", ROUTES)
async def test_legacy_duplicate_pending_rows_collapse_to_one(client, venues, route):
    owner = await _owner_at(venues["a"])
    id1, _ = await insert_invitation(venues["a"], email="dup@example.com", role="staff")
    id2, code2 = await insert_invitation(venues["a"], email="DUP@example.com", role="staff")
    id3, _ = await insert_invitation(venues["a"], email="dup@example.com", role="cashier")

    resp = await invite(client, route, venues["a"], owner, "dup@example.com", role="staff")

    assert resp.status_code == 200, resp.text
    assert resp.json()["id"] == id2            # newest same-role row is kept
    assert resp.json()["invitation_code"] == code2
    assert [r["id"] for r in await live_pending()] == [id2]
    assert (await invitation_by_id(id1))["status"] == "revoked"
    assert (await invitation_by_id(id3))["status"] == "revoked"


@pytest.mark.parametrize("route", ROUTES)
async def test_pending_invitation_at_another_venue_is_independent(client, venues, route):
    """Venue B neither sees, reuses, nor changes venue A's invitation."""
    owner_a = await _owner_at(venues["a"])
    owner_b = await _owner_at(venues["b"])
    at_a = await invite(client, route, venues["a"], owner_a, "both@example.com", role="admin")
    a_before = await invitation_by_id(at_a.json()["id"])

    at_b = await invite(client, route, venues["b"], owner_b, "both@example.com", role="staff")

    assert at_b.status_code == 200, at_b.text
    assert at_b.json()["bar_id"] == venues["b"]
    assert at_b.json()["id"] != at_a.json()["id"]
    assert at_b.json()["invitation_code"] != at_a.json()["invitation_code"]
    assert at_a.json()["invitation_code"] not in at_b.text
    a_after = await invitation_by_id(at_a.json()["id"])
    assert (a_after["status"], a_after["expires_at"]) == ("pending", a_before["expires_at"])


@pytest.mark.parametrize("route", ROUTES)
async def test_repeated_invites_never_create_duplicates(client, venues, route):
    owner = await _owner_at(venues["a"])

    codes = set()
    for _ in range(5):
        resp = await invite(client, route, venues["a"], owner, "spam@example.com")
        assert resp.status_code == 200, resp.text
        codes.add(resp.json()["invitation_code"])

    assert len(codes) == 1
    assert len(await invitations_for()) == 1


# ---------------------------------------------------------------------------
# No leaks: invitation codes and contact details never reach logs, or
# responses to users other than the inviter/recipient
# ---------------------------------------------------------------------------

SECRET_CODE = "SECRET-INVITE-CODE-123"
SECRET_EMAIL = "secret.person@example.com"
SECRET_PHONE = "+5511987650000"


def _assert_not_in_logs(caplog, *secrets):
    for record in caplog.records:
        if record.name.startswith(("httpx", "httpcore")):
            continue  # the test client logging its own outgoing request, not the server
        text = record.getMessage() + (record.exc_text or "")
        if record.exc_info:
            import traceback
            text += "".join(traceback.format_exception(*record.exc_info))
        for secret in secrets:
            assert secret not in text, (record.name, text)


class _DriverError(Exception):
    """Simulates a driver error that embeds row values, like asyncpg's
    'DETAIL: Key (invitation_code)=(...) already exists.'"""


@pytest.mark.parametrize("route", ROUTES)
async def test_db_error_on_create_is_sanitized(client, venues, route, monkeypatch, caplog):
    import logging
    from app.bars_and_restaurants.services import staff_invitations as svc

    monkeypatch.setattr(svc, "generate_invitation_code", lambda: SECRET_CODE)

    async def failing_persist(data):
        raise _DriverError(
            f'duplicate key value violates unique constraint "ix_staff_invitations_invitation_code" '
            f'DETAIL: Key (invitation_code)=({data["invitation_code"]}) already exists. '
            f'row=({data["email"]})'
        )

    monkeypatch.setattr(svc, "persist_staff_invitation", failing_persist)
    owner = await _owner_at(venues["a"])
    caplog.set_level(logging.DEBUG)

    resp = await invite(client, route, venues["a"], owner, SECRET_EMAIL)

    assert resp.status_code == 500
    assert resp.json() == {"error_code": "UNKNOWN", "message": "Could not create the invitation"}
    assert SECRET_CODE not in resp.text
    _assert_not_in_logs(caplog, SECRET_CODE, SECRET_EMAIL)
    failures = [r for r in caplog.records if "Staff invitation create failed" in r.getMessage()]
    assert len(failures) == 1
    assert "_DriverError" in failures[0].getMessage()
    assert failures[0].exc_info is None  # no traceback carrying the driver message
    assert await invitations_for() == []


@pytest.mark.parametrize("route", ROUTES)
async def test_db_error_on_resend_is_sanitized(client, venues, route, monkeypatch, caplog):
    import logging
    from app.bars_and_restaurants.services import staff_invitations as svc

    owner = await _owner_at(venues["a"])
    inv_id, _ = await insert_invitation(venues["a"], phone=SECRET_PHONE, code=SECRET_CODE)
    before = await invitation_by_id(inv_id)

    async def failing_renew(invitation_id):
        raise _DriverError(f"could not update row: code={SECRET_CODE} phone={SECRET_PHONE}")

    monkeypatch.setattr(svc, "renew_invitation", failing_renew)
    caplog.set_level(logging.DEBUG)

    resp = await invite(client, route, venues["a"], owner, SECRET_PHONE)

    assert resp.status_code == 500
    assert SECRET_CODE not in resp.text and SECRET_PHONE not in resp.text
    _assert_not_in_logs(caplog, SECRET_CODE, SECRET_PHONE)
    after = await invitation_by_id(inv_id)
    assert (after["status"], after["expires_at"]) == ("pending", before["expires_at"])


@pytest.mark.parametrize("route", ROUTES)
async def test_pending_conflict_discloses_nothing_about_the_invitation(client, venues, route):
    owner = await _owner_at(venues["a"])
    cashier, _ = await _member_with_role(venues["a"], "cashier")
    await insert_invitation(
        venues["a"], email=SECRET_EMAIL, role="admin", code=SECRET_CODE, invited_by_id=owner["id"],
    )

    resp = await invite(client, route, venues["a"], cashier, SECRET_EMAIL, role="staff")

    assert resp.status_code == 409
    body = resp.text
    for leaked in (SECRET_CODE, "admin", str(owner["id"]), owner["email"]):
        assert leaked not in body


async def test_unrelated_user_learns_nothing_from_someone_elses_code(client, venues):
    owner = await _owner_at(venues["a"])
    await make_user(email=SECRET_EMAIL, phone=SECRET_PHONE)
    outsider = await make_user(email="outsider@example.com")
    resp = await invite(client, "url", venues["a"], owner, SECRET_EMAIL, role="manager")
    code = resp.json()["invitation_code"]

    preview = await client.post(
        "/me/bars/invitations/preview", json={"invitation_code": code}, headers=headers_for(outsider),
    )
    accept = await client.post(
        "/me/bars/accept-invitation", json={"invitation_code": code}, headers=headers_for(outsider),
    )
    accept_q = await client.post(
        f"/me/bars/accept-invitation?invitation_code={code}", headers=headers_for(outsider),
    )
    pending = await client.get("/me/bars/invitations/pending", headers=headers_for(outsider))

    assert preview.status_code == accept.status_code == accept_q.status_code == 403
    assert pending.status_code == 200 and pending.json() == []
    masked = "s***********n@example.com"
    for r in (preview, accept, accept_q, pending):
        for leaked in (code, SECRET_EMAIL, SECRET_PHONE, masked, "Venue A", "manager"):
            assert leaked not in r.text, (r.request.url.path, leaked, r.text)
    assert (await invitations_for())[0]["status"] == "pending"


async def test_inviter_at_another_venue_never_receives_the_code(client, venues):
    owner_a = await _owner_at(venues["a"])
    owner_b = await _owner_at(venues["b"])
    at_a = await invite(client, "url", venues["a"], owner_a, SECRET_EMAIL, role="cashier")

    for route in ROUTES:
        at_b = await invite(client, route, venues["b"], owner_b, SECRET_EMAIL, role="cashier")
        assert at_b.status_code == 200
        assert at_a.json()["invitation_code"] not in at_b.text


@pytest.mark.parametrize("route", ROUTES)
async def test_request_validation_errors_do_not_echo_the_contact(client, venues, route):
    owner = await _owner_at(venues["a"])
    body = {"contact": SECRET_EMAIL, "role": ["not", "a", "string"]}
    if route == "url":
        resp = await client.post(f"/bars/{venues['a']}/staff/invite", json=body, headers=headers_for(owner))
    else:
        resp = await client.post("/staff/invite", json={**body, "bar_id": "nope"}, headers=headers_for(owner))

    assert resp.status_code == 422
    assert SECRET_EMAIL not in resp.text
    assert await invitations_for() == []


@pytest.mark.parametrize("path", [
    "/me/bars/accept-invitation?invitation_code=" + SECRET_CODE,
    "/me/bars/invitations/preview?invitation_code=" + SECRET_CODE,
])
def test_access_log_redacts_invitation_codes(path):
    import logging
    from app.logging_redaction import InvitationAccessLogFilter

    # uvicorn.access args: (client_addr, method, full_path, http_version, status_code)
    record = logging.LogRecord(
        "uvicorn.access", logging.INFO, __file__, 0,
        '%s - "%s %s HTTP/%s" %d', ("1.2.3.4:5", "POST", path, "1.1", 200), None,
    )
    InvitationAccessLogFilter().filter(record)

    assert SECRET_CODE not in record.getMessage()
    assert "[REDACTED]" in record.getMessage()


def test_access_log_redaction_is_installed():
    import logging
    from app.logging_redaction import InvitationAccessLogFilter

    assert any(
        isinstance(f, InvitationAccessLogFilter)
        for f in logging.getLogger("uvicorn.access").filters
    )


# ---------------------------------------------------------------------------
# Removing staff (DELETE /bars/{bar_id}/staff/{staff_id}) follows the rank
# rule: nobody can remove a member ranked above them.
# ---------------------------------------------------------------------------

async def remove_member(client, actor, bar_id, staff_id):
    return await client.delete(f"/bars/{bar_id}/staff/{staff_id}", headers=headers_for(actor))


async def is_active(staff_id):
    row = await test_database.fetch_one(BarStaff.__table__.select().where(BarStaff.id == staff_id))
    return bool(row["is_active"])


@pytest.mark.parametrize("actor_role", HIERARCHY)
@pytest.mark.parametrize("target_role", HIERARCHY)
async def test_remove_staff_matrix(client, venues, actor_role, target_role):
    actor, _ = await _member_with_role(venues["a"], actor_role)
    member = await make_user()
    member_staff_id = await add_staff(member["id"], venues["a"], target_role)

    resp = await remove_member(client, actor, venues["a"], member_staff_id)

    if target_role in ALLOWED_INVITES[actor_role]:
        assert resp.status_code == 200, resp.text
        assert not await is_active(member_staff_id)
    else:
        assert resp.status_code == 403, resp.text
        assert await is_active(member_staff_id)


@pytest.mark.parametrize("target_role", ["manager", "admin", "owner"])
async def test_cashier_cannot_remove_higher_ranked_staff(client, venues, target_role):
    cashier, _ = await _member_with_role(venues["a"], "cashier")
    member = await make_user()
    member_staff_id = await add_staff(member["id"], venues["a"], target_role)

    resp = await remove_member(client, cashier, venues["a"], member_staff_id)

    assert resp.status_code == 403, resp.text
    if target_role != "owner":  # owners keep the original message
        assert resp.json()["detail"] == (
            f"Cannot remove a {target_role}: role is above your own (cashier)"
        )
    assert await is_active(member_staff_id)
    listed = await client.get(f"/bars/{venues['a']}/staff", headers=headers_for(member))
    if target_role != "staff":
        assert member["id"] in [m["user_id"] for m in listed.json()]


async def test_removal_rank_uses_role_at_the_target_venue(client, venues):
    user = await make_user()
    await add_staff(user["id"], venues["a"], "owner")
    await add_staff(user["id"], venues["b"], "cashier", custom_permissions=["staff:manage"])
    admin_b = await make_user()
    admin_b_staff = await add_staff(admin_b["id"], venues["b"], "admin")

    resp = await remove_member(client, user, venues["b"], admin_b_staff)

    assert resp.status_code == 403, resp.text
    assert await is_active(admin_b_staff)


async def test_self_removal_within_rank_is_allowed(client, venues):
    cashier, staff_id = await _member_with_role(venues["a"], "cashier")

    resp = await remove_member(client, cashier, venues["a"], staff_id)

    assert resp.status_code == 200, resp.text
    assert not await is_active(staff_id)


# ---------------------------------------------------------------------------
# Acceptance flow errors are sanitized too (accept, preview, pending list)
# ---------------------------------------------------------------------------

class _FailingDatabase:
    """Delegates to the real database but fails reads on staff_invitations
    with a driver-style error embedding sensitive values."""

    def __init__(self, real, secrets_in_message):
        self._real = real
        self._message = " ".join(secrets_in_message)

    def __getattr__(self, name):
        return getattr(self._real, name)

    async def fetch_one(self, query, *args, **kwargs):
        if "staff_invitations" in str(query):
            raise _DriverError(f"DETAIL: Key (invitation_code)=({self._message}) failed")
        return await self._real.fetch_one(query, *args, **kwargs)

    async def fetch_all(self, query, *args, **kwargs):
        if "staff_invitations" in str(query):
            raise _DriverError(f"DETAIL: row ({self._message}) failed")
        return await self._real.fetch_all(query, *args, **kwargs)


async def _pending_invitation_for(client, venues, email=SECRET_EMAIL, phone=SECRET_PHONE):
    owner = await _owner_at(venues["a"])
    invitee = await make_user(email=email, phone=phone)
    resp = await invite(client, "url", venues["a"], owner, email, role="cashier")
    assert resp.status_code == 200, resp.text
    return invitee, resp.json()["invitation_code"]


def _sanitized_failures(caplog, action):
    records = [r for r in caplog.records if f"Staff invitation {action} failed" in r.getMessage()]
    assert len(records) == 1, [r.getMessage() for r in caplog.records]
    assert records[0].exc_info is None
    assert "error=_DriverError" in records[0].getMessage()
    return records[0]


async def test_accept_failure_inside_transaction_is_sanitized_and_rolled_back(
    client, venues, monkeypatch, caplog
):
    import logging
    import app.bars_and_restaurants.routes.staff as staff_routes

    invitee, code = await _pending_invitation_for(client, venues)

    async def failing_add_user_to_bar(*args, **kwargs):
        raise _DriverError(f"insert failed: code={code} email={SECRET_EMAIL} phone={SECRET_PHONE}")

    monkeypatch.setattr(staff_routes, "add_user_to_bar", failing_add_user_to_bar)
    caplog.set_level(logging.DEBUG)

    resp = await client.post(
        "/me/bars/accept-invitation", json={"invitation_code": code}, headers=headers_for(invitee),
    )

    assert resp.status_code == 500
    assert resp.json() == {"error_code": "UNKNOWN", "message": "Could not accept the invitation"}
    _assert_not_in_logs(caplog, code, SECRET_EMAIL, SECRET_PHONE)
    record = _sanitized_failures(caplog, "accept")
    assert f"user_id={invitee['id']}" in record.getMessage()

    # The claim was rolled back: still pending, no membership, and it can
    # still be accepted once the failure is gone.
    row = (await invitations_for())[0]
    assert (row["status"], row["accepted_by_user_id"]) == ("pending", None)
    assert await active_membership(invitee["id"], venues["a"]) is None
    monkeypatch.undo()
    staff_routes.database = test_database
    retry = await client.post(
        "/me/bars/accept-invitation", json={"invitation_code": code}, headers=headers_for(invitee),
    )
    assert retry.status_code == 200, retry.text


@pytest.mark.parametrize("how", ["body", "query"])
async def test_accept_lookup_failure_is_sanitized(client, venues, monkeypatch, caplog, how):
    import logging
    import app.bars_and_restaurants.routes.staff as staff_routes

    invitee, code = await _pending_invitation_for(client, venues)
    monkeypatch.setattr(
        staff_routes, "database", _FailingDatabase(test_database, [code, SECRET_EMAIL, SECRET_PHONE]),
    )
    caplog.set_level(logging.DEBUG)

    if how == "body":
        resp = await client.post(
            "/me/bars/accept-invitation", json={"invitation_code": code}, headers=headers_for(invitee),
        )
    else:
        resp = await client.post(
            f"/me/bars/accept-invitation?invitation_code={code}", headers=headers_for(invitee),
        )

    assert resp.status_code == 500
    assert resp.json() == {"error_code": "UNKNOWN", "message": "Could not accept the invitation"}
    _assert_not_in_logs(caplog, code, SECRET_EMAIL, SECRET_PHONE)
    _sanitized_failures(caplog, "accept")


async def test_preview_failure_is_sanitized(client, venues, monkeypatch, caplog):
    import logging
    import app.bars_and_restaurants.routes.staff as staff_routes

    invitee, code = await _pending_invitation_for(client, venues)
    monkeypatch.setattr(
        staff_routes, "database", _FailingDatabase(test_database, [code, SECRET_EMAIL, SECRET_PHONE]),
    )
    caplog.set_level(logging.DEBUG)

    resp = await client.post(
        "/me/bars/invitations/preview", json={"invitation_code": code}, headers=headers_for(invitee),
    )

    assert resp.status_code == 500
    assert resp.json() == {"error_code": "UNKNOWN", "message": "Could not preview the invitation"}
    _assert_not_in_logs(caplog, code, SECRET_EMAIL, SECRET_PHONE)
    _sanitized_failures(caplog, "preview")


async def test_pending_list_failure_is_sanitized(client, venues, monkeypatch, caplog):
    import logging
    import app.bars_and_restaurants.routes.staff as staff_routes

    invitee, code = await _pending_invitation_for(client, venues)
    monkeypatch.setattr(
        staff_routes, "database", _FailingDatabase(test_database, [code, SECRET_EMAIL, SECRET_PHONE]),
    )
    caplog.set_level(logging.DEBUG)

    resp = await client.get("/me/bars/invitations/pending", headers=headers_for(invitee))

    assert resp.status_code == 500
    assert resp.json() == {"error_code": "UNKNOWN", "message": "Could not load pending invitations"}
    _assert_not_in_logs(caplog, code, SECRET_EMAIL, SECRET_PHONE)
    _sanitized_failures(caplog, "list")


@pytest.mark.parametrize("route_call", ["accept", "preview"])
async def test_expected_acceptance_errors_are_not_masked(client, venues, route_call):
    """Sanitizing only covers unexpected failures; expected outcomes keep
    their status codes and error codes."""
    _, code = await _pending_invitation_for(client, venues)
    outsider = await make_user()
    path = "/me/bars/accept-invitation" if route_call == "accept" else "/me/bars/invitations/preview"

    wrong_user = await client.post(path, json={"invitation_code": code}, headers=headers_for(outsider))
    unknown = await client.post(path, json={"invitation_code": "nope"}, headers=headers_for(outsider))

    assert wrong_user.status_code == 403
    assert wrong_user.json()["error_code"] == "INVITATION_CONTACT_MISMATCH"
    assert unknown.status_code == 404
    assert unknown.json()["error_code"] == "INVITATION_INVALID"


def test_database_query_log_values_are_redacted():
    import logging
    from app.logging_redaction import DatabaseQueryArgsRedactionFilter

    record = logging.LogRecord(
        "databases", logging.DEBUG, __file__, 0, "Query: %s Args: %s",
        ("SELECT * FROM staff_invitations WHERE invitation_code = ?", repr((SECRET_CODE, SECRET_EMAIL))),
        None,
    )
    DatabaseQueryArgsRedactionFilter().filter(record)

    message = record.getMessage()
    assert SECRET_CODE not in message and SECRET_EMAIL not in message
    assert "WHERE invitation_code = ?" in message  # SQL kept for debugging
    assert message.endswith("Args: [REDACTED]")


def test_database_query_log_redaction_is_installed():
    import logging
    from app.logging_redaction import DatabaseQueryArgsRedactionFilter

    assert any(
        isinstance(f, DatabaseQueryArgsRedactionFilter)
        for f in logging.getLogger("databases").filters
    )


async def test_debug_logging_of_a_full_invite_and_accept_leaks_nothing(client, venues, caplog):
    """End to end at DEBUG level: invite, preview, accept. No log record
    carries the code or the invitee's contact details."""
    import logging
    caplog.set_level(logging.DEBUG)

    invitee, code = await _pending_invitation_for(client, venues)
    preview = await client.post(
        "/me/bars/invitations/preview", json={"invitation_code": code}, headers=headers_for(invitee),
    )
    accept = await client.post(
        f"/me/bars/accept-invitation?invitation_code={code}", headers=headers_for(invitee),
    )

    assert preview.status_code == accept.status_code == 200
    assert any(r.name == "databases" for r in caplog.records)  # DEBUG query logs were emitted
    _assert_not_in_logs(caplog, code, SECRET_EMAIL, SECRET_PHONE)


@pytest.mark.parametrize("fmt", ["executing %s", "operation %s completed", "returning exception %s"])
def test_aiosqlite_statement_logs_are_redacted(fmt):
    import functools
    import logging
    from app.logging_redaction import AiosqliteStatementRedactionFilter

    call = functools.partial(print, "SELECT * FROM users WHERE email = ?", [SECRET_EMAIL, SECRET_CODE])
    record = logging.LogRecord("aiosqlite", logging.DEBUG, __file__, 0, fmt, (call,), None)
    AiosqliteStatementRedactionFilter().filter(record)

    assert SECRET_EMAIL not in record.getMessage() and SECRET_CODE not in record.getMessage()
    assert "[REDACTED]" in record.getMessage()


def test_aiosqlite_redaction_is_installed():
    import logging
    from app.logging_redaction import AiosqliteStatementRedactionFilter

    assert any(
        isinstance(f, AiosqliteStatementRedactionFilter)
        for f in logging.getLogger("aiosqlite").filters
    )
