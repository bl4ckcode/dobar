from pydantic import BaseModel, EmailStr

class PhoneLogin(BaseModel):
    firebase_uid: str
    phone_number: str

class GoogleLogin(BaseModel):
    email: EmailStr
    google_id: str

class AppleLogin(BaseModel):
    email: EmailStr
    apple_id: str

class FacebookLogin(BaseModel):
    email: EmailStr
    facebook_id: str

class Token(BaseModel):
    access_token: str
    token_type: str