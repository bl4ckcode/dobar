def normalize_currency(currency: str, target: str = "stripe") -> str:
    if target == "stripe":
        return currency.lower()
    if target == "stone":
        return currency.upper()
    return currency