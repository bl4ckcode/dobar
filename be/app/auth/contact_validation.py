"""
Canonical validation for account contacts (email / phone).

A user's login contacts are set through these rules (see
``contact_change.normalize_contact``), and staff invitations are validated
with the same rules before they are stored, so every stored invitation
contact is one a real account can actually have.
"""

import re
from typing import Literal, Optional

from pydantic import EmailStr, TypeAdapter, ValidationError

# E.164: "+", country code (no leading 0), 8-15 digits total. ASCII digits
# only: ``\d`` would also accept Arabic-Indic, full-width, etc. digits.
PHONE_E164_RE = re.compile(r"^\+[1-9][0-9]{7,14}$")
# Formatting characters tolerated in user input and stripped before checking.
_PHONE_FORMATTING_RE = re.compile(r"[\s\-()]")
# "Phone-shaped": only ASCII digits and phone punctuation, at least one digit.
# Used to classify input, not to validate it (see ``canonical_phone``).
# Two single-repetition checks instead of one pattern with a digit between two
# repeated classes: that form backtracks quadratically on a long digit run
# that ends in a non-phone character.
_PHONE_CHARS_RE = re.compile(r"^[0-9+\s\-().]*$")
_ASCII_DIGIT_RE = re.compile(r"[0-9]")


def _is_phone_shaped(value: str) -> bool:
    return _PHONE_CHARS_RE.match(value) is not None and _ASCII_DIGIT_RE.search(value) is not None

_EMAIL = TypeAdapter(EmailStr)


class InvalidContact(ValueError):
    """Raised when an email or phone number is malformed."""


def classify_contact(value: Optional[str]) -> Optional[Literal["email", "phone"]]:
    """Decide what kind of contact ``value`` is meant to be, without validating.

    * contains "@"                          -> "email" (even if malformed)
    * only digits and phone punctuation
      (+ space - ( ) .), at least one digit -> "phone" (even if malformed)
    * anything else, including empty text   -> None: neither, and never
                                               treated as a phone number
    """
    value = (value or "").strip()
    if not value:
        return None
    if "@" in value:
        return "email"
    if _is_phone_shaped(value):
        return "phone"
    return None


def canonical_email(value: str) -> str:
    """Validate an email address and return it trimmed and lowercased.

    Raises InvalidContact if it is not a valid address.
    """
    try:
        return str(_EMAIL.validate_python((value or "").strip())).lower()
    except ValidationError:
        raise InvalidContact("Invalid email address")


def canonical_phone(value: str) -> str:
    """Validate a phone number and return it in E.164 (e.g. +5531999999999).

    Spaces, dashes and parentheses are tolerated and removed; anything else
    (letters, missing "+country code", wrong length) is rejected.

    Raises InvalidContact if it is not a valid E.164 number.
    """
    compact = _PHONE_FORMATTING_RE.sub("", (value or "").strip())
    if not PHONE_E164_RE.match(compact):
        raise InvalidContact("Invalid phone number")
    return compact
