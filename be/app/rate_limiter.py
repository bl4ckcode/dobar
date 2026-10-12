import os
from slowapi import Limiter
from slowapi.util import get_remote_address

REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6379")
TESTING = os.getenv("TESTING", "false").lower() == "true"

def key_func(request):
    user = getattr(request.state, "user", None)
    if user and hasattr(user, "id"):
        return f"user:{user.id}"
    return get_remote_address(request)

limiter = Limiter(
    key_func=key_func,
    storage_uri="memory://" if TESTING else REDIS_URL,
    default_limits=["200/minute"],
    enabled=not TESTING,
)

class RateLimits:
    ORDER_CREATE = "30/minute"
    PAYMENT_SUBMIT = "10/minute"
    MENU_FETCH = "100/minute"
    SEARCH = "60/minute"
    AUTH = "5/minute"
    MFA_CHALLENGE = "3/minute"
    RECOVERY = "3/minute"
    WAITLIST_SIGNUP = "5/hour"  # 5 requests per IP per hour for waitlist
    DEFAULT = "200/minute"
