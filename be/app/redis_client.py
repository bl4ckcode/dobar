import os
import json
import redis.asyncio as redis
from typing import Optional, Any, Callable
from functools import wraps

REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6379")

_redis_client: Optional[redis.Redis] = None

async def get_redis() -> redis.Redis:
    global _redis_client
    if _redis_client is None:
        _redis_client = redis.from_url(REDIS_URL, decode_responses=True)
    return _redis_client

async def close_redis():
    global _redis_client
    if _redis_client:
        await _redis_client.close()
        _redis_client = None

class CacheTTL:
    MENU = 300
    BAR = 300
    CATEGORIES = 3600
    PROMOTIONS = 60
    USER_SESSION = 86400
    SHORT = 60
    MEDIUM = 300
    LONG = 3600

class CacheService:
    @staticmethod
    async def get(key: str) -> Optional[Any]:
        client = await get_redis()
        try:
            data = await client.get(f"cache:{key}")
            return json.loads(data) if data else None
        except Exception:
            return None

    @staticmethod
    async def set(key: str, value: Any, ttl: int = CacheTTL.MEDIUM):
        client = await get_redis()
        try:
            await client.setex(f"cache:{key}", ttl, json.dumps(value, default=str))
        except Exception:
            pass

    @staticmethod
    async def delete(key: str):
        client = await get_redis()
        try:
            await client.delete(f"cache:{key}")
        except Exception:
            pass

    @staticmethod
    async def delete_pattern(pattern: str):
        client = await get_redis()
        try:
            cursor = 0
            while True:
                cursor, keys = await client.scan(cursor, match=f"cache:{pattern}", count=100)
                if keys:
                    await client.delete(*keys)
                if cursor == 0:
                    break
        except Exception:
            pass

    @staticmethod
    async def invalidate_bar(bar_id: int):
        await CacheService.delete_pattern(f"bar:{bar_id}:*")
        await CacheService.delete(f"bar:{bar_id}")

    @staticmethod
    async def invalidate_menu(bar_id: int):
        await CacheService.delete_pattern(f"menu:{bar_id}:*")

class WalletLock:
    LOCK_TTL = 5
    
    def __init__(self, user_id: int, idempotency_key: str):
        self.user_id = user_id
        self.idempotency_key = idempotency_key
        self.lock_key = f"wallet:lock:user:{user_id}"
        self._acquired = False
    
    async def acquire(self) -> bool:
        client = await get_redis()
        self._acquired = await client.set(
            self.lock_key,
            self.idempotency_key,
            nx=True,
            ex=self.LOCK_TTL
        )
        return self._acquired
    
    async def release(self):
        if self._acquired:
            client = await get_redis()
            await client.delete(self.lock_key)
            self._acquired = False
    
    async def __aenter__(self):
        acquired = await self.acquire()
        if not acquired:
            from app.errors import APIError
            raise APIError.conflict("Wallet operation in progress. Please try again.")
        return self
    
    async def __aexit__(self, exc_type, exc_val, exc_tb):
        await self.release()
        return False

class IdempotencyCache:
    TTL = 86400
    
    @staticmethod
    async def get(key: str) -> Optional[str]:
        client = await get_redis()
        return await client.get(f"idempotency:{key}")
    
    @staticmethod
    async def set(key: str, value: str):
        client = await get_redis()
        await client.setex(f"idempotency:{key}", IdempotencyCache.TTL, value)
    
    @staticmethod
    async def exists(key: str) -> bool:
        client = await get_redis()
        return await client.exists(f"idempotency:{key}") > 0
