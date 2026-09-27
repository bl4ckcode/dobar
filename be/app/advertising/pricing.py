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

PRICING_MODEL_BY_PLACEMENT = {
    "featured": "cph",
    "search": "cpc",
    "map_pin": "cph",
    "promo": "cpc",
    "banner": "cpm",
    "push_notification": "cpm",
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
