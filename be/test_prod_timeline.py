import jwt
import datetime
import httpx
import sys

# Production Secret key from .env
SECRET_KEY = "2040041e5d0f3116de7e8290ad65a366be7e1b7afa457a36459ae68689f13379"

def generate_token():
    payload = {
        "sub": "8",  # User ID from app.log
        "exp": datetime.datetime.utcnow() + datetime.timedelta(days=1),
        "iat": datetime.datetime.utcnow(),
        "type": "access"
    }
    return jwt.encode(payload, SECRET_KEY, algorithm="HS256")

token = generate_token()
print("Generated token:", token)

# Hit the production API
url = "https://barz-backend-bold-sun-5691.fly.dev/orders/1364/timeline"
headers = {"Authorization": f"Bearer {token}"}
response = httpx.get(url, headers=headers)
print("Status:", response.status_code)
print("Response:", response.text)
