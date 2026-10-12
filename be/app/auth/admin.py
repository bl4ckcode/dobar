import os
from typing import Optional
from fastapi import Depends, HTTPException, status, Header, Request
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import jwt, JWTError
from ..database import database
from .auth_models import User

security = HTTPBearer()

SECRET_KEY = os.getenv("SECRET_KEY", "fallback-secret-key")
ALGORITHM = "HS256"
ADMIN_API_KEY = os.getenv("ADMIN_API_KEY")


async def get_admin_user(
    credentials: HTTPAuthorizationCredentials = Depends(security)
) -> User:
    try:
        token = credentials.credentials
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id: str = payload.get("sub")
        
        if user_id is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid credentials",
                headers={"WWW-Authenticate": "Bearer"},
            )
        
        query = """
            SELECT u.id, u.email, u.is_active, p.user_type 
            FROM users u 
            LEFT JOIN user_profiles p ON p.user_id = u.id
            WHERE u.id = :user_id
        """
        user = await database.fetch_one(query=query, values={"user_id": int(user_id)})
        
        if user is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="User not found",
            )
        
        if not user.get("is_active", True):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="User account is inactive"
            )
        
        admin_emails = os.getenv("ADMIN_EMAILS", "").split(",")
        admin_emails = [e.strip().lower() for e in admin_emails if e.strip()]
        
        user_email = user.get("email", "")
        if not user_email or user_email.lower() not in admin_emails:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Admin access required"
            )
        
        return user
        
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )


async def verify_admin_api_key(
    x_admin_key: Optional[str] = Header(None, alias="X-Admin-Key")
) -> bool:
    if not ADMIN_API_KEY:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Admin API key not configured"
        )
    
    if x_admin_key != ADMIN_API_KEY:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Invalid admin API key"
        )
    
    return True


async def require_internal_or_admin(
    request: Request,
    x_admin_key: Optional[str] = Header(None, alias="X-Admin-Key"),
    x_internal_key: Optional[str] = Header(None, alias="X-Internal-Key"),
) -> bool:
    internal_key = os.getenv("INTERNAL_SERVICE_KEY")
    admin_key = os.getenv("ADMIN_API_KEY")
    
    if internal_key and x_internal_key == internal_key:
        return True
    
    if admin_key and x_admin_key == admin_key:
        return True
    
    client_ip = request.client.host if request.client else "unknown"
    trusted_ips = os.getenv("TRUSTED_IPS", "127.0.0.1,::1").split(",")
    trusted_ips = [ip.strip() for ip in trusted_ips]
    
    if client_ip in trusted_ips:
        return True
    
    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="Access denied. Admin or internal access required."
    )


RATE_LIMIT_STORE = {}

def get_rate_limiter(requests_per_minute: int = 60):
    async def rate_limit_check(request: Request):
        import time
        client_ip = request.client.host if request.client else "unknown"
        current_time = time.time()
        window_start = current_time - 60
        
        if client_ip not in RATE_LIMIT_STORE:
            RATE_LIMIT_STORE[client_ip] = []
        
        RATE_LIMIT_STORE[client_ip] = [
            ts for ts in RATE_LIMIT_STORE[client_ip] 
            if ts > window_start
        ]
        
        if len(RATE_LIMIT_STORE[client_ip]) >= requests_per_minute:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="Rate limit exceeded. Please try again later.",
                headers={"Retry-After": "60"}
            )
        
        RATE_LIMIT_STORE[client_ip].append(current_time)
        return True
    
    return rate_limit_check
