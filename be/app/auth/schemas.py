from pydantic import BaseModel, EmailStr
from typing import Optional

class PhoneLogin(BaseModel):
    firebase_uid: str
    phone_number: str

class GoogleLogin(BaseModel):
    id_token: str
    email: Optional[EmailStr] = None
    display_name: Optional[str] = None

class AppleLogin(BaseModel):
    id_token: str
    authorization_code: Optional[str] = None
    email: Optional[EmailStr] = None
    display_name: Optional[str] = None

class Token(BaseModel):
    access_token: str
    token_type: str
    is_new_user: bool = False