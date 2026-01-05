from pydantic import BaseModel, EmailStr
from typing import Optional

class PhoneLogin(BaseModel):
    firebase_uid: str
    phone_number: str
    # Optional: FE can send the Firebase token expiration timestamp (Unix seconds)
    token_expiration: Optional[int] = None

class GoogleLogin(BaseModel):
    id_token: str
    email: Optional[EmailStr] = None
    display_name: Optional[str] = None
    # Optional: FE can send the Google token expiration timestamp (Unix seconds)
    token_expiration: Optional[int] = None

class AppleLogin(BaseModel):
    id_token: str
    authorization_code: Optional[str] = None
    email: Optional[EmailStr] = None
    display_name: Optional[str] = None
    # Optional: FE can send the Apple token expiration timestamp (Unix seconds)
    token_expiration: Optional[int] = None

class Token(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str
    expires_in: int  # Seconds until access token expires
    is_new_user: bool = False

class RefreshTokenRequest(BaseModel):
    refresh_token: str

class LogoutRequest(BaseModel):
    refresh_token: Optional[str] = None  # Optional: revoke specific refresh token