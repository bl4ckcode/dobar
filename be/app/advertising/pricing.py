from decimal import Decimal, InvalidOperation
from typing import Any, Dict, List, Optional


DEFAULT_REGION_CODE = "BR"

DEFAULT_CREDITS: Dict[str, int] = {
    "featured_hours": 0,
    "search_clicks": 0,
    "map_hours": 0,
    "boost_impressions": 0,
}

CREDIT_BUCKETS = tuple(DEFAULT_CREDITS.keys())

# Legacy credit-key names found in real subscription rows (e.g. local barz_db
# advertising_subscriptions.id=4: {"banner": 100, "promo_boost": 50}). Both used to pay for
# impressions, and both placements consume `boost_impressions` today (CREDIT_BUCKET_BY_PLACEMENT),
# so they fold into that bucket additively. Without this, ensure_credits silently returned zeros
# for those rows. Only these two observed legacy names are aliased — unknown keys stay ignored.
LEGACY_CREDIT_ALIASES = {
    "banner": "boost_impressions",
    "promo_boost": "boost_impressions",
}

PLACEMENTS = ("featured", "search", "map_pin", "promo", "banner", "push_notification")

PLACEMENT_ALIASES = {
    "featured": "featured",
    "featured_home": "featured",
    "featuredhome": "featured",
    "home": "featured",
    "search": "search",
    "sponsored_search": "search",
    "sponsoredsearch": "search",
    "map": "map_pin",
    "map_pin": "map_pin",
    "mappin": "map_pin",
    "map_spotlight": "map_pin",
    "mapspotlight": "map_pin",
    "promo": "promo",
    "promo_boost": "promo",
    "promoboost": "promo",
    "banner": "banner",
    "banners": "banner",
    "push": "push_notification",
    "push_notification": "push_notification",
}

CAMPAIGN_TYPE_BY_PLACEMENT = {
    "featured": "featured",
    "search": "search",
    "map_pin": "map",
    "promo": "promo_boost",
    "banner": "banner",
    "push_notification": "push_notification",
}

CREDIT_BUCKET_BY_PLACEMENT: Dict[str, Optional[str]] = {
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

# Ground truth for the promo model: .docs/q4_2026/Dobar_Market_Analysis_Brazil_2026.pdf,
# §5.2 "Product 4: Promotion Boost (CPM)" — promo is priced per 1,000 impressions, not per click.
# `promo` reads its rate from the regional `boost_cpm` column (see REGION_RATE_FIELDS) and consumes the
# `boost_impressions` credit bucket, so it reports the CPM model like `banner` / `push_notification`.
PRICING_MODEL_BY_PLACEMENT = {
    "featured": "cph",
    "search": "cpc",
    "map_pin": "cph",
    "promo": "cpm",
    "banner": "cpm",
    "push_notification": "cpm",
}

# API-legal `budget_type` token for each pricing model. The pricing model itself (`cph`) is NOT a
# legal `budget_type`: `cph` is absent from BudgetTypeEnum (schemas.py) and from the DB `BudgetType`
# enum (models.py), where the per-hour model is spelled `hourly`. The rate card advertises the token
# from this map (never the raw model), and POST /advertising/campaigns validates against it.
BUDGET_TYPE_BY_PRICING_MODEL = {
    "cph": "hourly",
    "cpc": "cpc",
    "cpm": "cpm",
}

# Reverse of CAMPAIGN_TYPE_BY_PLACEMENT — canonical placement for a stored campaign_type value.
PLACEMENT_BY_CAMPAIGN_TYPE = {
    campaign_type: placement
    for placement, campaign_type in CAMPAIGN_TYPE_BY_PLACEMENT.items()
}

RATE_UNIT_BY_PRICING_MODEL = {
    "cph": "per_hour",
    "cpc": "per_click",
    "cpm": "per_1000_impressions",
}

REGION_RATE_FIELDS = {
    "featured": ("featured_cph", None),
    "search": ("search_cpc_min", "search_cpc_max"),
    "map_pin": ("map_cph", None),
    "promo": ("boost_cpm", None),
    "banner": ("boost_cpm", None),
    "push_notification": ("boost_cpm", None),
}

MIN_DAILY_BUDGETS = {
    "featured": Decimal("40.00"),
    "search": Decimal("20.00"),
    "map_pin": Decimal("25.00"),
    "promo": Decimal("15.00"),
    "banner": Decimal("30.00"),
    "push_notification": Decimal("25.00"),
}

DEFAULT_MIN_DAILY_BUDGET = Decimal("15.00")

ESTIMATION_DAYS = 7


def as_decimal(value: Any, default: Decimal = Decimal("0")) -> Decimal:
    if isinstance(value, Decimal):
        return value
    if value is None or value == "":
        return default
    try:
        return Decimal(str(value))
    except (InvalidOperation, TypeError, ValueError):
        return default


def normalize_placement(raw: Any) -> Optional[str]:
    if raw is None:
        return None
    key = str(raw).strip().lower().replace("-", "_").replace(" ", "_")
    return PLACEMENT_ALIASES.get(key, key if key in PLACEMENTS else None)


def credit_bucket_for_placement(placement: Any) -> Optional[str]:
    return CREDIT_BUCKET_BY_PLACEMENT.get(normalize_placement(placement) or "")


def placement_for_campaign_type(campaign_type: Any) -> Optional[str]:
    """Canonical placement for a stored campaign_type value (`promo_boost` → `promo`)."""
    if campaign_type is None:
        return None
    return PLACEMENT_BY_CAMPAIGN_TYPE.get(str(campaign_type))


def allowed_budget_types_for_placement(placement: Any, has_rate: bool) -> List[str]:
    """
    The `budget_type` values a placement accepts — the single source used both to build the
    rate card's `allowed_budget_types` and to validate `POST /advertising/campaigns`, so the
    FE-doc promise ("exactly the budget_type values accepted by create") holds by construction.

    Order (documented in .docs/FE_BE_COMMUNICATION.md §4): credits (if credit-backed),
    the API-legal pricing-model token (only when the region has a configured rate > 0),
    then `fixed`, which is always present.
    """
    allowed: List[str] = []
    if credit_bucket_for_placement(placement):
        allowed.append("credits")
    pricing_model = PRICING_MODEL_BY_PLACEMENT.get(placement)
    if has_rate and pricing_model:
        allowed.append(BUDGET_TYPE_BY_PRICING_MODEL[pricing_model])
    allowed.append("fixed")
    return allowed


def primary_placement(distribution: Any) -> Optional[str]:
    best = None
    best_percentage = -1.0
    for entry in distribution or []:
        if hasattr(entry, "model_dump"):
            entry = entry.model_dump()
        if not isinstance(entry, dict):
            continue
        placement = normalize_placement(entry.get("placement"))
        percentage = float(as_decimal(entry.get("percentage")))
        if placement and percentage > best_percentage:
            best, best_percentage = placement, percentage
    return best


def infer_campaign_type(distribution: Any) -> Optional[str]:
    placement = primary_placement(distribution)
    return CAMPAIGN_TYPE_BY_PLACEMENT.get(placement) if placement else None


def ensure_credits(value: Any) -> Dict[str, int]:
    if not isinstance(value, dict):
        return dict(DEFAULT_CREDITS)
    credits = dict(DEFAULT_CREDITS)
    for bucket in CREDIT_BUCKETS:
        raw = value.get(bucket)
        try:
            credits[bucket] = int(raw) if raw is not None else 0
        except (TypeError, ValueError):
            credits[bucket] = 0
    # Fold legacy keys additively so pre-migration rows keep their balance (B6 decision:
    # alias-at-read instead of a one-off data migration — see .docs/FE_BE_COMMUNICATION.md §10).
    for legacy_key, bucket in LEGACY_CREDIT_ALIASES.items():
        raw = value.get(legacy_key)
        if raw is None:
            continue
        try:
            credits[bucket] += int(raw)
        except (TypeError, ValueError):
            continue
    return credits


def ensure_placement_credits(value: Any) -> Dict[str, int]:
    if not isinstance(value, dict):
        return {}
    preserved: Dict[str, int] = {}
    for key, raw in value.items():
        try:
            preserved[key] = int(raw)
        except (TypeError, ValueError):
            preserved[key] = 0
    return preserved


def distribution_to_storage(distribution: Any) -> List[Dict[str, Any]]:
    stored: List[Dict[str, Any]] = []
    for entry in distribution or []:
        if hasattr(entry, "model_dump"):
            entry = entry.model_dump()
        if not isinstance(entry, dict):
            continue
        stored.append({
            "placement": normalize_placement(entry.get("placement")) or entry.get("placement"),
            "percentage": float(as_decimal(entry.get("percentage"))),
            "budget": float(as_decimal(entry.get("budget"))),
        })
    return stored


def normalize_distribution(raw: Any, budget_amount: Any = None) -> Any:
    if raw is None:
        return None

    entries: List[Dict[str, Any]] = []

    if isinstance(raw, dict):
        iterable = raw.items()
    elif isinstance(raw, (list, tuple)):
        iterable = [(None, entry) for entry in raw]
    else:
        return raw

    for key, entry in iterable:
        if hasattr(entry, 'model_dump'):
            entry = entry.model_dump()
        elif hasattr(entry, 'dict'):
            entry = entry.dict()
        
        if isinstance(entry, dict):
            placement = normalize_placement(entry.get("placement", key)) or entry.get("placement", key)
            percentage = entry.get("percentage", entry.get("share"))
            budget = entry.get("budget", entry.get("amount"))
        else:
            placement = normalize_placement(key) or key
            percentage = entry
            budget = None

        if percentage is None and budget is None:
            raise ValueError("Each placement_distribution entry requires 'percentage' or 'budget'")

        entries.append({"placement": placement, "percentage": percentage, "budget": budget})

    total_budget = as_decimal(budget_amount, Decimal("0"))

    for entry in entries:
        percentage = entry["percentage"]
        budget = entry["budget"]

        if percentage is None:
            if total_budget <= 0:
                raise ValueError("'budget' per placement requires budget_amount to derive percentages")
            entry["percentage"] = round(float(as_decimal(budget) / total_budget * 100), 2)
        else:
            entry["percentage"] = round(float(as_decimal(percentage)), 2)

        if budget is None:
            entry["budget"] = (total_budget * as_decimal(entry["percentage"]) / 100).quantize(Decimal("0.01"))
        else:
            entry["budget"] = as_decimal(budget).quantize(Decimal("0.01"))

    return entries
