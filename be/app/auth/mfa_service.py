import pyotp
import secrets
import json
from typing import List, Optional
from datetime import datetime, timedelta, timezone
from jose import jwt
import os

SECRET_KEY = os.getenv("SECRET_KEY", "fallback-secret-key")
ALGORITHM = "HS256"
MFA_TOKEN_EXPIRE_MINUTES = 5
APP_NAME = "Dobar"


def generate_secret() -> str:
    return pyotp.random_base32()


def generate_qr_uri(secret: str, email: str) -> str:
    totp = pyotp.TOTP(secret)
    return totp.provisioning_uri(name=email or "user", issuer_name=APP_NAME)


def verify_totp(secret: str, code: str) -> bool:
    totp = pyotp.TOTP(secret)
    return totp.verify(code, valid_window=1)


def generate_backup_codes(count: int = 8) -> List[str]:
    return [secrets.token_hex(4).upper() for _ in range(count)]


def serialize_backup_codes(codes: List[str]) -> str:
    return json.dumps(codes)


def deserialize_backup_codes(raw: Optional[str]) -> List[str]:
    if not raw:
        return []
    return json.loads(raw)


def create_mfa_token(user_id: int) -> str:
    now = datetime.now(timezone.utc)
    payload = {
        "sub": str(user_id),
        "exp": now + timedelta(minutes=MFA_TOKEN_EXPIRE_MINUTES),
        "iat": now,
        "type": "mfa_challenge",
    }
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)


def verify_mfa_token(token: str) -> Optional[int]:
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        if payload.get("type") != "mfa_challenge":
            return None
        user_id = payload.get("sub")
        return int(user_id) if user_id else None
    except Exception:
        return None


def use_backup_code(stored_codes: List[str], code: str) -> tuple[bool, List[str]]:
    upper_code = code.upper()
    if upper_code in stored_codes:
        remaining = [c for c in stored_codes if c != upper_code]
        return True, remaining
    return False, stored_codes
