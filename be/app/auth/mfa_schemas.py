from pydantic import BaseModel
from typing import Optional, List


class MFASetupResponse(BaseModel):
    secret: str
    qr_code_uri: str
    backup_codes: List[str]


class MFAVerifyRequest(BaseModel):
    totp_code: str


class MFAChallengeRequest(BaseModel):
    totp_code: Optional[str] = None
    sms_code: Optional[str] = None
    backup_code: Optional[str] = None


class MFAChallengeResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int
    is_new_user: bool = False


class MFAStatusResponse(BaseModel):
    is_enabled: bool
    phone_fallback_enabled: bool
