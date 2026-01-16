import os
import redis.asyncio as redis
from typing import Optional

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
