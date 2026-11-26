"""
Venue-scoped authorization for menu and menu-item mutations.

Every route under ``/menus`` requires an authenticated user. Any logged-in
user (customers included) may browse; every mutating route additionally
requires the matching menu permission *at the venue that owns the menu*:

    create menu / add items (single, bulk)   -> menu:create  (owner, admin, manager)
    update menu / update item / availability -> menu:edit    (owner, admin, manager)
    delete menu / delete item                -> menu:delete  (owner, admin)

Response bodies are unchanged for authorized callers.
"""

import json

import pytest

from conftest import create_test_token, test_database
from app.auth.auth_models import User
from app.auth.rbac_models import BarStaff
from app.bars_and_restaurants.models.relational_models import (
    Bar, Menu as MenuModel, MenuItem as MenuItemModel,
)


pytestmark = pytest.mark.asyncio


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_counter = {"n": 0}


def _next():
    _counter["n"] += 1
    return _counter["n"]


async def make_user():
    n = _next()
    user_id = await test_database.execute(User.__table__.insert().values(
        firebase_uid=f"menu-uid-{n}",
        email=f"menu-user{n}@example.com",
        phone_number=f"+55118{n:08d}",
        is_active=True,
        email_verified=True,
        phone_verified=False,
    ))
    return {"id": user_id}


async def make_bar(owner_id, name):
    return await test_database.execute(Bar.__table__.insert().values(
        name=name,
        address=f"{_next()} {name} St",
        phone_number="+5511000000000",
        email=f"{name.lower().replace(' ', '')}@bar.test",
        owner_id=owner_id,
    ))


async def make_menu(bar_id, name="Menu"):
    return await test_database.execute(MenuModel.__table__.insert().values(
        bar_id=bar_id, name=name, description="desc", is_active=True,
    ))


async def make_item(menu_id, name="Caipirinha", price=20.0, available=True):
    return await test_database.execute(MenuItemModel.__table__.insert().values(
        menu_id=menu_id, name=name, price=price, available=available,
        category="drinks", display_order=0,
    ))


async def add_staff(user_id, bar_id, role, custom_permissions=None, is_active=True):
    if isinstance(custom_permissions, list):
        custom_permissions = json.dumps(custom_permissions)
    await test_database.execute(BarStaff.__table__.insert().values(
        user_id=user_id,
        bar_id=bar_id,
        role=role,
        custom_permissions=custom_permissions,
        is_active=is_active,
    ))


def headers_for(user, **extra):
    return {"Authorization": f"Bearer {create_test_token(user['id'])}", **extra}


async def get_menu_row(menu_id):
    return await test_database.fetch_one(
        MenuModel.__table__.select().where(MenuModel.id == menu_id)
    )


async def get_item_row(item_id):
    return await test_database.fetch_one(
        MenuItemModel.__table__.select().where(MenuItemModel.id == item_id)
    )


async def count_menus(bar_id):
    return len(await test_database.fetch_all(
        MenuModel.__table__.select().where(MenuModel.bar_id == bar_id)
    ))


async def count_items(menu_id):
    return len(await test_database.fetch_all(
        MenuItemModel.__table__.select().where(MenuItemModel.menu_id == menu_id)
    ))


@pytest.fixture
async def venue(client, test_bar_owner_in_db):
    """Venue A (the target) with one menu and one item, plus an unrelated venue B."""
    owner_ref = test_bar_owner_in_db["id"]
    bar_a = await make_bar(owner_ref, "Venue A")
    bar_b = await make_bar(owner_ref, "Venue B")
    menu_a = await make_menu(bar_a, "Menu A")
    item_a = await make_item(menu_a, "Item A")
    menu_b = await make_menu(bar_b, "Menu B")
    item_b = await make_item(menu_b, "Item B")
    return {
        "bar_a": bar_a, "bar_b": bar_b,
        "menu_a": menu_a, "item_a": item_a,
        "menu_b": menu_b, "item_b": item_b,
    }


# Each mutation: name -> (required permission, request builder, "was it applied?" check)

ITEM_BODY = {"name": "New Item", "price": 12.5, "category": "drinks"}


def _req_create_menu(v, bar_key="bar_a"):
    return ("POST", "/menus/", {"json": {"bar_id": v[bar_key], "name": "New Menu"}})


def _req_update_menu(v, menu_key="menu_a"):
    return ("PUT", f"/menus/{v[menu_key]}", {"json": {"name": "Renamed"}})


def _req_delete_menu(v, menu_key="menu_a"):
    return ("DELETE", f"/menus/{v[menu_key]}", {})


def _req_create_item(v, menu_key="menu_a"):
    return ("POST", f"/menus/{v[menu_key]}/items", {"json": ITEM_BODY})


def _req_bulk_items(v, menu_key="menu_a"):
    return ("POST", f"/menus/{v[menu_key]}/items/bulk",
            {"json": {"items": [ITEM_BODY, {**ITEM_BODY, "name": "Other"}]}})


def _req_update_item(v, menu_key="menu_a", item_key="item_a"):
    return ("PUT", f"/menus/{v[menu_key]}/items/{v[item_key]}",
            {"json": {"price": 99.0}})


def _req_delete_item(v, menu_key="menu_a", item_key="item_a"):
    return ("DELETE", f"/menus/{v[menu_key]}/items/{v[item_key]}", {})


def _req_toggle_item(v, menu_key="menu_a", item_key="item_a"):
    return ("PATCH", f"/menus/{v[menu_key]}/items/{v[item_key]}/availability",
            {"params": {"available": "false"}})


MUTATIONS = {
    "create_menu": ("menu:create", _req_create_menu),
    "update_menu": ("menu:edit", _req_update_menu),
    "delete_menu": ("menu:delete", _req_delete_menu),
    "create_item": ("menu:create", _req_create_item),
    "bulk_items": ("menu:create", _req_bulk_items),
    "update_item": ("menu:edit", _req_update_item),
    "delete_item": ("menu:delete", _req_delete_item),
    "toggle_item": ("menu:edit", _req_toggle_item),
}


async def snapshot(v):
    """State of venue A's menu data, used to prove a rejected call changed nothing."""
    menu = await get_menu_row(v["menu_a"])
    item = await get_item_row(v["item_a"])
    return {
        "menus_a": await count_menus(v["bar_a"]),
        "items_a": await count_items(v["menu_a"]),
        "menu": dict(menu) if menu else None,
        "item": dict(item) if item else None,
    }


async def send(client, mutation, v, headers=None, extra_params=None, **builder_kwargs):
    method, url, kwargs = MUTATIONS[mutation][1](v, **builder_kwargs)
    kwargs = dict(kwargs)
    if extra_params:
        kwargs["params"] = {**kwargs.get("params", {}), **extra_params}
    return await client.request(method, url, headers=headers or {}, **kwargs)


# ---------------------------------------------------------------------------
# Rejections: every mutation, nothing changes
# ---------------------------------------------------------------------------

@pytest.mark.parametrize("mutation", list(MUTATIONS))
async def test_anonymous_cannot_mutate(client, venue, mutation):
    before = await snapshot(venue)

    resp = await send(client, mutation, venue)

    assert resp.status_code == 401, resp.text
    assert await snapshot(venue) == before


@pytest.mark.parametrize("mutation", list(MUTATIONS))
async def test_customer_without_membership_cannot_mutate(client, venue, mutation):
    customer = await make_user()
    before = await snapshot(venue)

    resp = await send(client, mutation, venue, headers=headers_for(customer))

    assert resp.status_code == 403, resp.text
    assert await snapshot(venue) == before


@pytest.mark.parametrize("mutation", list(MUTATIONS))
async def test_owner_of_another_venue_cannot_mutate(client, venue, mutation):
    other_owner = await make_user()
    await add_staff(other_owner["id"], venue["bar_b"], "owner")
    before = await snapshot(venue)

    resp = await send(client, mutation, venue, headers=headers_for(other_owner))

    assert resp.status_code == 403, resp.text
    assert await snapshot(venue) == before


@pytest.mark.parametrize("mutation", list(MUTATIONS))
async def test_other_venue_context_via_header_or_query_is_ignored(client, venue, mutation):
    """Authorization must use the menu's venue, never the X-Bar-Id header or
    a ``bar_id`` query param pointing at a venue where the caller is owner."""
    other_owner = await make_user()
    await add_staff(other_owner["id"], venue["bar_b"], "owner")
    before = await snapshot(venue)

    resp = await send(
        client, mutation, venue,
        headers=headers_for(other_owner, **{"X-Bar-Id": str(venue["bar_b"])}),
        extra_params={"bar_id": str(venue["bar_b"])},
    )

    assert resp.status_code == 403, resp.text
    assert await snapshot(venue) == before


@pytest.mark.parametrize("mutation", list(MUTATIONS))
async def test_inactive_membership_cannot_mutate(client, venue, mutation):
    former_owner = await make_user()
    await add_staff(former_owner["id"], venue["bar_a"], "owner", is_active=False)
    before = await snapshot(venue)

    resp = await send(client, mutation, venue, headers=headers_for(former_owner))

    assert resp.status_code == 403, resp.text
    assert await snapshot(venue) == before


@pytest.mark.parametrize("mutation", list(MUTATIONS))
@pytest.mark.parametrize("role", ["staff", "cashier"])
async def test_view_only_roles_cannot_mutate(client, venue, mutation, role):
    member = await make_user()
    await add_staff(member["id"], venue["bar_a"], role)
    before = await snapshot(venue)

    resp = await send(client, mutation, venue, headers=headers_for(member))

    assert resp.status_code == 403, resp.text
    assert await snapshot(venue) == before


@pytest.mark.parametrize("mutation", list(MUTATIONS))
async def test_custom_permissions_for_other_actions_do_not_grant_this_one(client, venue, mutation):
    """A member holding every menu permission *except* the required one is rejected."""
    required = MUTATIONS[mutation][0]
    others = [p for p in ("menu:view", "menu:create", "menu:edit", "menu:delete") if p != required]
    member = await make_user()
    await add_staff(member["id"], venue["bar_a"], "staff", custom_permissions=others)
    before = await snapshot(venue)

    resp = await send(client, mutation, venue, headers=headers_for(member))

    assert resp.status_code == 403, resp.text
    assert await snapshot(venue) == before


# ---------------------------------------------------------------------------
# Allowed: roles and custom permissions
# ---------------------------------------------------------------------------

@pytest.mark.parametrize("mutation", list(MUTATIONS))
@pytest.mark.parametrize("role", ["owner", "admin"])
async def test_owner_and_admin_can_mutate(client, venue, mutation, role):
    member = await make_user()
    await add_staff(member["id"], venue["bar_a"], role)

    resp = await send(client, mutation, venue, headers=headers_for(member))

    assert resp.status_code == 200, resp.text
    assert resp.headers["X-Bar-Id"] == str(venue["bar_a"])
    assert resp.headers["X-Bar-Role"] == role
    assert MUTATIONS[mutation][0] in resp.headers["X-Bar-Permissions"].split(",")


@pytest.mark.parametrize("mutation", list(MUTATIONS))
async def test_custom_permission_grants_exactly_that_action(client, venue, mutation):
    required = MUTATIONS[mutation][0]
    member = await make_user()
    await add_staff(member["id"], venue["bar_a"], "staff", custom_permissions=[required])

    resp = await send(client, mutation, venue, headers=headers_for(member))

    assert resp.status_code == 200, resp.text
    assert resp.headers["X-Bar-Role"] == "staff"


@pytest.mark.parametrize("mutation,expected", [
    ("create_menu", 200),
    ("update_menu", 200),
    ("delete_menu", 403),
    ("create_item", 200),
    ("bulk_items", 200),
    ("update_item", 200),
    ("delete_item", 403),
    ("toggle_item", 200),
])
async def test_manager_role_defaults(client, venue, mutation, expected):
    """Managers can save (create) and edit menus, but not delete them."""
    manager = await make_user()
    await add_staff(manager["id"], venue["bar_a"], "manager")
    before = await snapshot(venue)

    resp = await send(client, mutation, venue, headers=headers_for(manager))

    assert resp.status_code == expected, resp.text
    if expected == 403:
        assert await snapshot(venue) == before


async def test_manager_can_save_a_new_menu_with_bulk_import(client, venue):
    """The full "save imported menu" flow: create a menu, then bulk-add items."""
    manager = await make_user()
    await add_staff(manager["id"], venue["bar_a"], "manager")
    headers = headers_for(manager)

    resp = await client.post("/menus/", headers=headers,
                             json={"bar_id": venue["bar_a"], "name": "Imported"})
    assert resp.status_code == 200, resp.text
    new_menu = resp.json()["id"]
    assert resp.json()["bar_id"] == venue["bar_a"]
    assert resp.headers["X-Bar-Role"] == "manager"
    assert "menu:create" in resp.headers["X-Bar-Permissions"].split(",")

    items = [{"name": f"Imported {i}", "price": 10.0 + i, "category": "drinks"}
             for i in range(3)]
    resp = await client.post(f"/menus/{new_menu}/items/bulk", headers=headers,
                             json={"items": items})
    assert resp.status_code == 200, resp.text
    assert resp.json()["created_count"] == 3
    assert await count_items(new_menu) == 3


async def test_manager_cannot_save_menus_at_another_venue(client, venue):
    manager = await make_user()
    await add_staff(manager["id"], venue["bar_b"], "manager")
    before = await snapshot(venue)

    for mutation in ("create_menu", "create_item", "bulk_items"):
        resp = await send(client, mutation, venue, headers=headers_for(manager))
        assert resp.status_code == 403, (mutation, resp.text)

    assert await snapshot(venue) == before


async def test_manager_permissions_reported_to_frontend(client, venue):
    """/me/bars drives front-end gating; managers must see menu:create there."""
    manager = await make_user()
    await add_staff(manager["id"], venue["bar_a"], "manager")

    resp = await client.get("/me/bars", headers=headers_for(manager))

    assert resp.status_code == 200, resp.text
    [bar] = resp.json()
    assert bar["role"] == "manager"
    assert {"menu:view", "menu:edit", "menu:create"} <= set(bar["permissions"])
    assert "menu:delete" not in bar["permissions"]


# ---------------------------------------------------------------------------
# Effects and response shapes for authorized callers (unchanged API)
# ---------------------------------------------------------------------------

@pytest.fixture
async def owner_a(venue):
    owner = await make_user()
    await add_staff(owner["id"], venue["bar_a"], "owner")
    return headers_for(owner)


async def test_create_menu_shape(client, venue, owner_a):
    resp = await send(client, "create_menu", venue, headers=owner_a)
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["bar_id"] == venue["bar_a"]
    assert body["name"] == "New Menu"
    assert set(body) == {"id", "bar_id", "name", "description", "is_active",
                         "created_at", "updated_at"}
    assert await count_menus(venue["bar_a"]) == 2


async def test_update_menu_shape(client, venue, owner_a):
    resp = await send(client, "update_menu", venue, headers=owner_a)
    assert resp.status_code == 200, resp.text
    assert resp.json()["id"] == venue["menu_a"]
    assert resp.json()["name"] == "Renamed"
    assert (await get_menu_row(venue["menu_a"]))["name"] == "Renamed"


async def test_delete_menu_shape(client, venue, owner_a):
    resp = await send(client, "delete_menu", venue, headers=owner_a)
    assert resp.status_code == 200, resp.text
    assert resp.json() == {"message": "Menu deleted successfully", "id": venue["menu_a"]}
    assert await get_menu_row(venue["menu_a"]) is None


async def test_create_item_shape(client, venue, owner_a):
    resp = await send(client, "create_item", venue, headers=owner_a)
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["menu_id"] == venue["menu_a"]
    assert body["name"] == "New Item"
    assert await count_items(venue["menu_a"]) == 2


async def test_bulk_items_shape(client, venue, owner_a):
    resp = await send(client, "bulk_items", venue, headers=owner_a)
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["created_count"] == 2
    assert {i["menu_id"] for i in body["items"]} == {venue["menu_a"]}
    assert await count_items(venue["menu_a"]) == 3


async def test_update_item_shape(client, venue, owner_a):
    resp = await send(client, "update_item", venue, headers=owner_a)
    assert resp.status_code == 200, resp.text
    assert resp.json()["id"] == venue["item_a"]
    assert resp.json()["price"] == 99.0
    assert float((await get_item_row(venue["item_a"]))["price"]) == 99.0


async def test_delete_item_shape(client, venue, owner_a):
    resp = await send(client, "delete_item", venue, headers=owner_a)
    assert resp.status_code == 200, resp.text
    assert resp.json() == {"message": "Menu item deleted successfully", "id": venue["item_a"]}
    assert await get_item_row(venue["item_a"]) is None


async def test_toggle_item_shape(client, venue, owner_a):
    resp = await send(client, "toggle_item", venue, headers=owner_a)
    assert resp.status_code == 200, resp.text
    assert resp.json() == {"item_id": venue["item_a"], "available": False}
    assert (await get_item_row(venue["item_a"]))["available"] is False


# ---------------------------------------------------------------------------
# Not found and cross-menu item ids
# ---------------------------------------------------------------------------

@pytest.mark.parametrize("mutation", [m for m in MUTATIONS if m != "create_menu"])
async def test_missing_menu_is_404_for_authenticated_user(client, venue, owner_a, mutation):
    v = {**venue, "menu_a": 999999}
    resp = await send(client, mutation, v, headers=owner_a)
    assert resp.status_code == 404, resp.text


async def test_create_menu_for_missing_venue_is_404(client, venue, owner_a):
    resp = await send(client, "create_menu", {**venue, "bar_a": 999999}, headers=owner_a)
    assert resp.status_code == 404, resp.text


@pytest.mark.parametrize("mutation", ["update_item", "delete_item", "toggle_item"])
async def test_item_from_another_venue_cannot_be_reached_through_own_menu(
    client, venue, owner_a, mutation
):
    """Owner of venue A addresses venue B's item through venue A's menu path."""
    before = dict(await get_item_row(venue["item_b"]))

    resp = await send(client, mutation, venue, headers=owner_a,
                      menu_key="menu_a", item_key="item_b")

    assert resp.status_code == 404, resp.text
    assert dict(await get_item_row(venue["item_b"])) == before


# ---------------------------------------------------------------------------
# Browsing requires login; any logged-in user (customers included) may browse
# ---------------------------------------------------------------------------

def _read_routes(v):
    return [
        f"/menus/bar/{v['bar_a']}",
        f"/menus/{v['menu_a']}",
        f"/menus/{v['menu_a']}/full",
        f"/menus/{v['menu_a']}/items",
        f"/menus/{v['menu_a']}/items/{v['item_a']}",
        f"/menus/items/{v['menu_a']}",
        "/menus/trending/drinks",
        "/menus/trending/categories",
    ]


READ_ROUTE_COUNT = 8


@pytest.mark.parametrize("idx", range(READ_ROUTE_COUNT))
async def test_anonymous_cannot_browse(client, venue, idx):
    resp = await client.get(_read_routes(venue)[idx])
    assert resp.status_code == 401, resp.text


@pytest.mark.parametrize("idx", range(READ_ROUTE_COUNT))
async def test_invalid_token_cannot_browse(client, venue, idx):
    resp = await client.get(_read_routes(venue)[idx],
                            headers={"Authorization": "Bearer not-a-real-token"})
    assert resp.status_code == 401, resp.text


async def test_inactive_user_cannot_browse(client, venue):
    user = await make_user()
    await test_database.execute(
        User.__table__.update().where(User.id == user["id"]).values(is_active=False)
    )
    resp = await client.get(f"/menus/{venue['menu_a']}/full", headers=headers_for(user))
    assert resp.status_code == 403, resp.text


async def test_logged_in_customer_can_browse(client, venue):
    """A customer with no venue membership sees the same data as before."""
    customer = await make_user()
    h = headers_for(customer)
    bar_a, menu_a, item_a = venue["bar_a"], venue["menu_a"], venue["item_a"]

    resp = await client.get(f"/menus/bar/{bar_a}", headers=h)
    assert resp.status_code == 200, resp.text
    assert [m["id"] for m in resp.json()] == [menu_a]

    resp = await client.get(f"/menus/{menu_a}", headers=h)
    assert resp.status_code == 200, resp.text
    assert resp.json()["bar_id"] == bar_a

    resp = await client.get(f"/menus/{menu_a}/full", headers=h)
    assert resp.status_code == 200, resp.text
    assert [i["id"] for i in resp.json()["items"]] == [item_a]

    resp = await client.get(f"/menus/{menu_a}/items", headers=h,
                            params={"available_only": "true"})
    assert resp.status_code == 200, resp.text
    assert [i["id"] for i in resp.json()] == [item_a]

    resp = await client.get(f"/menus/{menu_a}/items/{item_a}", headers=h)
    assert resp.status_code == 200, resp.text
    assert resp.json()["name"] == "Item A"

    resp = await client.get(f"/menus/items/{menu_a}", headers=h)
    assert resp.status_code == 200, resp.text
    assert resp.json()["items"][0]["id"] == item_a

    resp = await client.get("/menus/trending/categories", headers=h)
    assert resp.status_code == 200, resp.text
    # /menus/trending/drinks uses PostgreSQL-only SQL (NOW(), INTERVAL), so it
    # is only covered by the 401 tests above on the SQLite test database.


async def test_customer_can_browse_other_venues_menus(client, venue):
    """Browsing is not venue-scoped: staff of venue B can read venue A's menu."""
    staff_b = await make_user()
    await add_staff(staff_b["id"], venue["bar_b"], "staff")
    resp = await client.get(f"/menus/{venue['menu_a']}/full", headers=headers_for(staff_b))
    assert resp.status_code == 200, resp.text
    assert resp.json()["id"] == venue["menu_a"]
