from typing import Literal

CURRENCY_MAP = {
    "stripe": {
        "BRL": "brl", "USD": "usd", "EUR": "eur", "MXN": "mxn",
        "ARS": "ars", "CLP": "clp", "COP": "cop", "PEN": "pen",
    },
    "paypal": {
        "BRL": "BRL", "USD": "USD", "EUR": "EUR", "MXN": "MXN",
        "ARS": "ARS", "CLP": "CLP", "COP": "COP", "PEN": "PEN",
    },
}

def normalize_currency(
    currency: str,
    target: Literal["stripe", "paypal"] = "stripe"
) -> str:
    mapping = CURRENCY_MAP.get(target, {})
    return mapping.get(currency.upper(), currency.lower() if target == "stripe" else currency.upper())

def to_cents(amount: float) -> int:
    return int(round(amount * 100))

def from_cents(cents: int) -> float:
    return cents / 100.0
