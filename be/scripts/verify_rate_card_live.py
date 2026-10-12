#!/usr/bin/env python3
"""Live contract check for `GET /advertising/rates`.

Re-verifies the canonical rate-card schema documented in `.docs/FE_BE_COMMUNICATION.md`
(section "ADVERTISING RATE CARD — GET /advertising/rates") against a running deployment, so the
contract the Flutter app parses cannot silently drift. Works offline too, via `--self-test`.

Usage
-----
    # production (needs a principal holding `ads:view` on the bar)
    python scripts/verify_rate_card_live.py --user-id 8 --bar-id 16

    # any deployment, including local
    python scripts/verify_rate_card_live.py --base-url local --user-id 8
    python scripts/verify_rate_card_live.py --base-url https://staging.example.dev --user-id 8

    # bring your own short-lived token instead of minting one
    python scripts/verify_rate_card_live.py --token "$BARZ_TOKEN" --bar-id 16

    # offline: run every assertion against an embedded fixture (no token, no network)
    python scripts/verify_rate_card_live.py --self-test

    # inside the deployed app container (secret never leaves the machine: the mint falls back
    # to the container's own $SECRET_KEY; note flyctl's -C execs without a shell, so no cd/&&)
    flyctl ssh console -a barz-backend-bold-sun-5691 -C \
        'python /app/scripts/verify_rate_card_live.py --base-url http://127.0.0.1:8080 --user-id 6 --bar-id 16'

Environment
-----------
    BARZ_BASE_URL     default target URL, or "local" for http://localhost:8000
    BARZ_BAR_ID       bar to query
    BARZ_USER_ID      principal used when minting a token
    BARZ_JWT_SECRET   JWT secret used to mint (same value as the app's SECRET_KEY)
    SECRET_KEY        fallback for the above — the app's own env var, so runs *inside* the
                      app container need no secret flag or env at all
    BARZ_TOKEN        pre-existing bearer token; takes precedence over minting

Exit code: 0 when every check passes, 1 otherwise, so CI can gate on it.
"""

from __future__ import annotations

import argparse
import copy
import datetime as dt
import json
import os
import sys
from typing import Callable

import httpx

DEFAULT_BASE_URL = "https://barz-backend-bold-sun-5691.fly.dev"
LOCAL_BASE_URL = "http://localhost:8000"
JWT_ALGORITHM = "HS256"

CANONICAL_PLACEMENTS = ("featured", "search", "map_pin", "promo", "banner", "push_notification")

# Mirror of app/advertising/pricing.py — kept explicit on purpose: this script exists to fail loudly
# when the served contract diverges from these expectations.
PRICING_MODEL_BY_PLACEMENT = {
    "featured": "cph",
    "search": "cpc",
    "map_pin": "cph",
    "promo": "cpm",  # ground truth: Dobar_Market_Analysis_Brazil_2026.pdf §5.2 "Promotion Boost (CPM)"
    "banner": "cpm",
    "push_notification": "cpm",
}
RATE_UNIT_BY_PRICING_MODEL = {
    "cph": "per_hour",
    "cpc": "per_click",
    "cpm": "per_1000_impressions",
}
CAMPAIGN_TYPE_BY_PLACEMENT = {
    "featured": "featured",
    "search": "search",
    "map_pin": "map",
    "promo": "promo_boost",
    "banner": "banner",
    "push_notification": "push_notification",
}
CREDIT_BUCKET_BY_PLACEMENT = {
    "featured": "featured_hours",
    "search": "search_clicks",
    "map_pin": "map_hours",
    "promo": "boost_impressions",
    "banner": "boost_impressions",
    "push_notification": None,
}
CREDIT_UNIT_BY_BUCKET = {
    "featured_hours": "hours",
    "search_clicks": "clicks",
    "map_hours": "hours",
    "boost_impressions": "impressions",
}
CREDIT_BUCKETS = ("featured_hours", "search_clicks", "map_hours", "boost_impressions")
# `cph` is deliberately absent: it is a pricing model, never a legal budget_type (A3 decision).
# The rate card advertises the API-legal token instead (`cph` → `hourly`).
KNOWN_BUDGET_TYPES = {"credits", "fixed", "cpc", "cpm", "hourly"}
BUDGET_TYPE_BY_PRICING_MODEL = {
    "cph": "hourly",
    "cpc": "cpc",
    "cpm": "cpm",
}
# Mirror of routes._get_allowed_campaign_types — what each tier may create (A2 decision:
# promo_boost widened to master per PDF §5.2 "Master + VIP"; banner/map stay VIP-only).
ALLOWED_CAMPAIGN_TYPES_BY_TIER = {
    "vip": ["featured", "search", "map", "promo_boost", "banner", "push_notification"],
    "master": ["featured", "search", "push_notification", "promo_boost"],
}
MONEY_FIELDS = ("rate", "min_daily_budget")
MIN_DAILY_BUDGETS = {
    "featured": "40.00",
    "search": "20.00",
    "map_pin": "25.00",
    "promo": "15.00",
    "banner": "30.00",
    "push_notification": "25.00",
}
# The three placements that read the regional `boost_cpm` column, and therefore share one rate.
BOOST_CPM_PLACEMENTS = ("promo", "banner", "push_notification")


class Checker:
    """Collects pass/fail results instead of aborting on the first failure."""

    def __init__(self) -> None:
        self.results: list[tuple[str, bool, str]] = []

    def check(self, label: str, condition: bool, detail: str = "") -> bool:
        self.results.append((label, bool(condition), detail))
        return bool(condition)

    @property
    def failures(self) -> list[tuple[str, bool, str]]:
        return [item for item in self.results if not item[1]]

    @property
    def passed(self) -> int:
        return len(self.results) - len(self.failures)


def _money(value) -> float | None:
    """Tolerant parse — the contract says money fields are strings, but report clearly if they are not."""
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def verify_rate_card(payload: dict) -> Checker:
    """Assert every invariant the FE relies on. `payload` is the JSON body of GET /advertising/rates."""
    c = Checker()

    if not isinstance(payload, dict):
        c.check("response body is a JSON object", False, type(payload).__name__)
        return c

    for key in ("region_code", "currency", "tier", "placements", "credit_buckets",
                "credits_by_tier", "credits_available"):
        c.check(f"top-level `{key}` present", key in payload)

    c.check("`currency` is a string", isinstance(payload.get("currency"), str),
            repr(payload.get("currency")))
    c.check("`region_code` is a string", isinstance(payload.get("region_code"), str),
            repr(payload.get("region_code")))

    placements = payload.get("placements")
    if not isinstance(placements, dict):
        c.check("`placements` is an object", False, type(placements).__name__)
        return c

    c.check("all six canonical placements returned", set(placements) == set(CANONICAL_PLACEMENTS),
            f"got {sorted(placements)}")

    rates: dict[str, object] = {}

    for name in CANONICAL_PLACEMENTS:
        entry = placements.get(name)
        if not isinstance(entry, dict):
            c.check(f"`{name}` entry is an object", False, type(entry).__name__)
            continue

        rates[name] = entry.get("rate")

        c.check(f"`{name}.placement` echoes the canonical key", entry.get("placement") == name,
                repr(entry.get("placement")))
        c.check(f"`{name}.campaign_type` == {CAMPAIGN_TYPE_BY_PLACEMENT[name]!r}",
                entry.get("campaign_type") == CAMPAIGN_TYPE_BY_PLACEMENT[name],
                repr(entry.get("campaign_type")))
        c.check(f"`{name}.pricing_model` == {PRICING_MODEL_BY_PLACEMENT[name]!r}",
                entry.get("pricing_model") == PRICING_MODEL_BY_PLACEMENT[name],
                repr(entry.get("pricing_model")))
        c.check(f"`{name}.rate_unit` matches its pricing_model",
                entry.get("rate_unit") == RATE_UNIT_BY_PRICING_MODEL.get(entry.get("pricing_model")),
                repr(entry.get("rate_unit")))

        for field in MONEY_FIELDS:
            value = entry.get(field)
            c.check(f"`{name}.{field}` is a JSON string (not a number)",
                    isinstance(value, str), f"{type(value).__name__} = {value!r}")

        rate_max = entry.get("rate_max")
        c.check(f"`{name}.rate_max` is null or a JSON string",
                rate_max is None or isinstance(rate_max, str), repr(rate_max))

        allowed = entry.get("allowed_budget_types")
        if not isinstance(allowed, list):
            c.check(f"`{name}.allowed_budget_types` is a list", False, repr(allowed))
            allowed = []

        c.check(f"`{name}.allowed_budget_types` holds only known budget types",
                all(isinstance(v, str) and v in KNOWN_BUDGET_TYPES for v in allowed), repr(allowed))
        c.check(f"`{name}.allowed_budget_types` never contains the pricing-model token 'cph'",
                "cph" not in allowed, repr(allowed))
        c.check(f"`{name}.allowed_budget_types` has no duplicates",
                len(allowed) == len(set(allowed)), repr(allowed))
        c.check(f"`{name}.allowed_budget_types` always contains 'fixed'", "fixed" in allowed,
                repr(allowed))

        # Composition mirrors routes.get_rate_card: credits (if credit-backed)
        # + API-legal pricing-model token (if rate > 0) + fixed.
        rate_value = _money(entry.get("rate")) or 0.0
        expected_types = []
        if entry.get("credit_bucket"):
            expected_types.append("credits")
        if rate_value > 0:
            expected_types.append(BUDGET_TYPE_BY_PRICING_MODEL[PRICING_MODEL_BY_PLACEMENT[name]])
        expected_types.append("fixed")
        c.check(f"`{name}.allowed_budget_types` == {expected_types}", allowed == expected_types,
                repr(allowed))

        # A2: `usable` mirrors the create-endpoint tier gate for this tier.
        expected_usable = (
            CAMPAIGN_TYPE_BY_PLACEMENT[name]
            in ALLOWED_CAMPAIGN_TYPES_BY_TIER.get(payload.get("tier"), [])
        )
        c.check(f"`{name}.usable` is a boolean",
                isinstance(entry.get("usable"), bool), repr(entry.get("usable")))
        c.check(f"`{name}.usable` == {expected_usable} for tier={payload.get('tier')!r}",
                entry.get("usable") is expected_usable, repr(entry.get("usable")))

        bucket = entry.get("credit_bucket")
        expected_bucket = CREDIT_BUCKET_BY_PLACEMENT[name]
        c.check(f"`{name}.credit_bucket` == {expected_bucket!r}", bucket == expected_bucket,
                repr(bucket))
        c.check(f"`{name}.credit_backed` == bool(credit_bucket)",
                entry.get("credit_backed") == bool(expected_bucket), repr(entry.get("credit_backed")))
        c.check(f"`{name}.credit_unit` is consistent with its bucket",
                entry.get("credit_unit") == CREDIT_UNIT_BY_BUCKET.get(expected_bucket or ""),
                f"{entry.get('credit_unit')!r} != {CREDIT_UNIT_BY_BUCKET.get(expected_bucket or '')!r}")
        c.check(f"`{name}.min_daily_budget` is the documented value",
                entry.get("min_daily_budget") == MIN_DAILY_BUDGETS[name],
                f"{entry.get('min_daily_budget')!r} != {MIN_DAILY_BUDGETS[name]!r}")

        if name == "search":
            c.check("`search.rate_max` is populated (the only ranged placement)",
                    isinstance(rate_max, str), repr(rate_max))
        else:
            c.check(f"`{name}.rate_max` is null (only `search` has a range)",
                    rate_max is None, repr(rate_max))

    # The promo money shot: CPM, not CPC (aligned Sep 25, 2026 — see the market-analysis PDF §5.2).
    promo = placements.get("promo") or {}
    c.check("`promo.pricing_model` is 'cpm'",
            promo.get("pricing_model") == "cpm", repr(promo.get("pricing_model")))
    c.check("`promo.rate_unit` is 'per_1000_impressions'",
            promo.get("rate_unit") == "per_1000_impressions", repr(promo.get("rate_unit")))
    c.check("`promo.allowed_budget_types` == ['credits', 'cpm', 'fixed']",
            promo.get("allowed_budget_types") == ["credits", "cpm", "fixed"],
            repr(promo.get("allowed_budget_types")))

    shared_rates = {rates.get(name) for name in BOOST_CPM_PLACEMENTS}
    c.check("`promo`/`banner`/`push_notification` share one `boost_cpm` rate", len(shared_rates) == 1,
            f"rates={ {name: rates.get(name) for name in BOOST_CPM_PLACEMENTS} }")

    search_rate = _money((placements.get("search") or {}).get("rate"))
    search_max = _money((placements.get("search") or {}).get("rate_max"))
    if search_rate and search_max:
        c.check("`search.rate` <= `search.rate_max`", search_rate <= search_max,
                f"{search_rate} > {search_max}")

    c.check("`credit_buckets` lists the four buckets in canonical order",
            list(payload.get("credit_buckets") or []) == list(CREDIT_BUCKETS),
            repr(payload.get("credit_buckets")))

    by_tier = payload.get("credits_by_tier")
    c.check("`credits_by_tier` exposes master and vip",
            isinstance(by_tier, dict) and {"master", "vip"} <= set(by_tier or {}),
            repr(sorted((by_tier or {}).keys())) if isinstance(by_tier, dict) else repr(by_tier))
    for tier in ("master", "vip"):
        tier_credits = (by_tier or {}).get(tier) if isinstance(by_tier, dict) else None
        c.check(f"`credits_by_tier.{tier}` has all four integer buckets",
                isinstance(tier_credits, dict)
                and set(tier_credits) == set(CREDIT_BUCKETS)
                and all(isinstance(v, int) for v in tier_credits.values()),
                repr(tier_credits))

    available = payload.get("credits_available")
    c.check("`credits_available` has all four integer buckets",
            isinstance(available, dict)
            and set(available) == set(CREDIT_BUCKETS)
            and all(isinstance(v, int) for v in available.values()),
            repr(available))

    return c


# =============================================================================
# Offline self-test: fixture + mutations that must be caught
# =============================================================================

def _fixture() -> dict:
    """The documented Master/BR example (boost_cpm = 8.00, as seeded by the contract test)."""

    def placement(name: str, rate: str, rate_max=None) -> dict:
        bucket = CREDIT_BUCKET_BY_PLACEMENT[name]
        allowed = (["credits"] if bucket else []) + [BUDGET_TYPE_BY_PRICING_MODEL[PRICING_MODEL_BY_PLACEMENT[name]]] + ["fixed"]
        return {
            "placement": name,
            "campaign_type": CAMPAIGN_TYPE_BY_PLACEMENT[name],
            "pricing_model": PRICING_MODEL_BY_PLACEMENT[name],
            "rate": rate,
            "rate_max": rate_max,
            "rate_unit": RATE_UNIT_BY_PRICING_MODEL[PRICING_MODEL_BY_PLACEMENT[name]],
            "credit_bucket": bucket,
            "credit_unit": CREDIT_UNIT_BY_BUCKET.get(bucket or ""),
            "credit_backed": bool(bucket),
            "min_daily_budget": MIN_DAILY_BUDGETS[name],
            "allowed_budget_types": allowed,
            # master tier below → mirrors the create-endpoint tier gate
            "usable": CAMPAIGN_TYPE_BY_PLACEMENT[name] in ALLOWED_CAMPAIGN_TYPES_BY_TIER["master"],
        }

    return {
        "region_code": "BR",
        "currency": "BRL",
        "tier": "master",
        "placements": {
            "featured": placement("featured", "25.00"),
            "search": placement("search", "0.80", "2.50"),
            "map_pin": placement("map_pin", "35.00"),
            "promo": placement("promo", "8.00"),
            "banner": placement("banner", "8.00"),
            "push_notification": placement("push_notification", "8.00"),
        },
        "credit_buckets": list(CREDIT_BUCKETS),
        "credits_by_tier": {
            "master": {"featured_hours": 4, "search_clicks": 200, "map_hours": 2,
                       "boost_impressions": 5000},
            "vip": {"featured_hours": 12, "search_clicks": 1000, "map_hours": 8,
                    "boost_impressions": 25000},
        },
        "credits_available": {"featured_hours": 0, "search_clicks": 0, "map_hours": 0,
                              "boost_impressions": 0},
    }


def _mutations() -> list[tuple[str, "Callable[[dict], None]"]]:
    """Each mutation breaks one documented invariant, so the checker must report at least one failure."""

    def rate_as_number(payload: dict) -> None:
        payload["placements"]["featured"]["rate"] = 25.0

    def promo_back_to_cpc(payload: dict) -> None:
        payload["placements"]["promo"]["pricing_model"] = "cpc"
        payload["placements"]["promo"]["rate_unit"] = "per_click"

    def drop_a_placement(payload: dict) -> None:
        payload["placements"].pop("banner")

    def rate_max_on_promo(payload: dict) -> None:
        payload["placements"]["promo"]["rate_max"] = "9.00"

    def credit_backed_flipped(payload: dict) -> None:
        payload["placements"]["promo"]["credit_backed"] = False

    def missing_vip_credits(payload: dict) -> None:
        payload["credits_by_tier"].pop("vip")

    def budget_types_reordered(payload: dict) -> None:
        payload["placements"]["promo"]["allowed_budget_types"] = ["fixed", "cpm", "credits"]

    def cph_advertised_as_budget_type(payload: dict) -> None:
        # A3: `cph` is a pricing model, not a budget_type — the card must never advertise it.
        payload["placements"]["featured"]["allowed_budget_types"] = ["credits", "cph", "fixed"]

    def usable_flipped(payload: dict) -> None:
        # A2: master may not buy `map` — usable must be False for map_pin on a master card.
        payload["placements"]["map_pin"]["usable"] = True

    def legacy_credit_key(payload: dict) -> None:
        # B6: legacy keys fold at read time — the response must only ever expose canonical buckets.
        payload["credits_available"]["promo_boost"] = payload["credits_available"].pop(
            "boost_impressions"
        )

    return [
        ("rate serialized as a number", rate_as_number),
        ("promo relabelled cpc", promo_back_to_cpc),
        ("placement missing", drop_a_placement),
        ("rate_max set on a non-search placement", rate_max_on_promo),
        ("credit_backed inconsistent", credit_backed_flipped),
        ("credits_by_tier missing vip", missing_vip_credits),
        ("allowed_budget_types out of documented order", budget_types_reordered),
        ("pricing-model token cph advertised as budget_type", cph_advertised_as_budget_type),
        ("usable flipped against the tier gate", usable_flipped),
        ("legacy credit key leaking into credits_available", legacy_credit_key),
    ]


def self_test() -> int:
    print("🧪 Offline self-test — no network, no token\n")

    baseline = verify_rate_card(_fixture())
    print(f"  fixture: {baseline.passed} checks passed, {len(baseline.failures)} failed")
    for label, _, detail in baseline.failures:
        print(f"    ❌ {label}  ({detail})")
    ok = not baseline.failures

    for name, mutate in _mutations():
        payload = copy.deepcopy(_fixture())
        mutate(payload)
        caught = verify_rate_card(payload).failures
        if caught:
            print(f"  ✅ detected: {name}")
        else:
            print(f"  ❌ NOT detected: {name}")
            ok = False

    print("\n✅ self-test passed" if ok else "\n❌ self-test failed")
    return 0 if ok else 1


# =============================================================================
# Live mode
# =============================================================================

def resolve_base_url(raw: str | None) -> str:
    value = (raw or os.getenv("BARZ_BASE_URL") or DEFAULT_BASE_URL).strip()
    if value.lower() == "local":
        return LOCAL_BASE_URL
    return value.rstrip("/")


def mint_token(user_id: int, secret: str) -> str:
    """Mint a short-lived access token with the same payload shape as app/auth/routes.create_access_token."""
    import jwt  # PyJWT — the library the API itself uses

    now = dt.datetime.now(dt.timezone.utc)
    payload = {
        "sub": str(user_id),
        "exp": now + dt.timedelta(hours=1),
        "iat": now,
        "type": "access",
    }
    return jwt.encode(payload, secret, algorithm=JWT_ALGORITHM)


def resolve_token(args) -> tuple[str | None, str]:
    """Precedence: --token > $BARZ_TOKEN > mint from --user-id + secret."""
    provided = args.token or os.getenv("BARZ_TOKEN")
    if provided:
        return provided, "provided token"
    # BARZ_JWT_SECRET first; $SECRET_KEY is the app's own env var, which makes the minting work
    # out-of-the-box when the script runs *inside* the app container (flyctl ssh console) —
    # in that case the secret never leaves the machine that already owns it.
    secret = args.jwt_secret or os.getenv("BARZ_JWT_SECRET") or os.getenv("SECRET_KEY")
    if secret and args.user_id:
        return mint_token(args.user_id, secret), f"minted for user {args.user_id} (1h)"
    return None, "none"


def _env_int(name: str) -> int | None:
    raw = os.getenv(name)
    return int(raw) if raw and raw.isdigit() else None


def _report(checker: Checker, heading: str) -> bool:
    print(heading)
    for label, ok, detail in checker.results:
        if not ok:
            print(f"  ❌ {label}  ({detail})")
    print(f"  {checker.passed}/{len(checker.results)} checks passed")
    return not checker.failures


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Live contract check for GET /advertising/rates.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument("--base-url", default=None,
                        help="target URL, or 'local' for http://localhost:8000 "
                             f"(default: $BARZ_BASE_URL or {DEFAULT_BASE_URL})")
    parser.add_argument("--bar-id", type=int, default=_env_int("BARZ_BAR_ID"),
                        help="bar to query (also sent as X-Bar-Id on the second call)")
    parser.add_argument("--user-id", type=int, default=_env_int("BARZ_USER_ID"),
                        help="principal used when minting a token; must hold ads:view on the bar")
    parser.add_argument("--token", default=None, help="existing bearer token ($BARZ_TOKEN)")
    parser.add_argument("--jwt-secret", default=None,
                        help="JWT secret used to mint a token "
                             "($BARZ_JWT_SECRET, else the app's $SECRET_KEY)")
    parser.add_argument("--self-test", action="store_true",
                        help="run every assertion offline against an embedded fixture")
    parser.add_argument("--dump", action="store_true", help="print the raw JSON response")
    args = parser.parse_args()

    if args.self_test:
        return self_test()

    base_url = resolve_base_url(args.base_url)
    token, token_source = resolve_token(args)

    print("🍺 Rate-card contract check")
    print(f"   target : {base_url}")
    print(f"   auth   : {token_source}")
    print(f"   bar    : {args.bar_id if args.bar_id is not None else '(resolved from the token)'}\n")

    if not token:
        print("❌ No credentials.\n"
              "   Pass --token, or --user-id together with --jwt-secret (or set BARZ_TOKEN /\n"
              "   BARZ_JWT_SECRET / SECRET_KEY). Run --self-test to exercise the checks offline instead.")
        return 1

    headers = {"Authorization": f"Bearer {token}"}
    if args.bar_id is not None:
        headers["X-Bar-Id"] = str(args.bar_id)

    with httpx.Client(base_url=base_url, timeout=30) as client:
        params = {"bar_id": args.bar_id} if args.bar_id is not None else None
        response = client.get("/advertising/rates", params=params, headers=headers)
        query = f"?bar_id={args.bar_id}" if args.bar_id is not None else ""
        print(f"GET /advertising/rates{query} → {response.status_code}")

        if response.status_code != 200:
            print(f"❌ expected 200, got {response.status_code}: {response.text[:500]}")
            if response.status_code in (401, 403):
                print("   The token must belong to a user holding `ads:view` on the target bar\n"
                      "   (owner/admin by default; a manager needs the custom grant).")
            return 1

        payload = response.json()
        if args.dump:
            print(json.dumps(payload, indent=2, ensure_ascii=False))

        observed = payload.get("placements") or {}
        print(f"   tier={payload.get('tier')} region={payload.get('region_code')} "
              f"currency={payload.get('currency')}")
        for name in CANONICAL_PLACEMENTS:
            entry = observed.get(name) or {}
            print(f"   {name:18} model={str(entry.get('pricing_model')):4} "
                  f"rate={entry.get('rate')!r:10} rate_max={entry.get('rate_max')!r:8} "
                  f"bucket={entry.get('credit_bucket')!r}")
        print()

        overall_ok = _report(verify_rate_card(payload), "Checks (query-parameter form):")

        if args.bar_id is not None:
            header_only = client.get("/advertising/rates", headers=headers)
            print(f"\nGET /advertising/rates with X-Bar-Id only → {header_only.status_code}")
            if header_only.status_code == 200:
                echoed = header_only.headers.get("X-Bar-Id")
                print(f"   X-Bar-Id echoed: {echoed!r}")
                overall_ok = _report(verify_rate_card(header_only.json()),
                                     "Checks (header-only form):") and overall_ok
            else:
                overall_ok = False

    print("\n✅ contract holds" if overall_ok else "\n❌ contract drift detected")
    return 0 if overall_ok else 1


if __name__ == "__main__":
    sys.exit(main())




