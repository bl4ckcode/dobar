from enum import Enum
from typing import Dict, Any, Optional, List, Callable
from dataclasses import dataclass, field
from datetime import datetime, timezone
import asyncio
import json
import uuid
import os

try:
    import redis.asyncio as aioredis
    REDIS_AVAILABLE = True
except ImportError:
    REDIS_AVAILABLE = False


class JobStatus(str, Enum):
    PENDING = "pending"
    PROCESSING = "processing"
    COMPLETED = "completed"
    FAILED = "failed"
    RETRYING = "retrying"


@dataclass
class Job:
    id: str
    operation: str
    payload: Dict[str, Any]
    status: JobStatus = JobStatus.PENDING
    result: Optional[Dict[str, Any]] = None
    error: Optional[str] = None
    attempts: int = 0
    max_attempts: int = 3
    created_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))
    updated_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))
    
    def to_dict(self) -> Dict[str, Any]:
        return {
            "id": self.id,
            "operation": self.operation,
            "payload": json.dumps(self.payload),
            "status": self.status.value,
            "result": json.dumps(self.result) if self.result else "",
            "error": self.error or "",
            "attempts": str(self.attempts),
            "max_attempts": str(self.max_attempts),
            "created_at": self.created_at.isoformat(),
            "updated_at": self.updated_at.isoformat(),
        }
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "Job":
        return cls(
            id=data["id"],
            operation=data["operation"],
            payload=json.loads(data["payload"]) if data.get("payload") else {},
            status=JobStatus(data.get("status", "pending")),
            result=json.loads(data["result"]) if data.get("result") else None,
            error=data.get("error") or None,
            attempts=int(data.get("attempts", 0)),
            max_attempts=int(data.get("max_attempts", 3)),
            created_at=datetime.fromisoformat(data["created_at"]) if data.get("created_at") else datetime.now(timezone.utc),
            updated_at=datetime.fromisoformat(data["updated_at"]) if data.get("updated_at") else datetime.now(timezone.utc),
        )


class RedisJobQueue:
    STREAM_KEY = "dobar:payments:jobs"
    CONSUMER_GROUP = "payment-workers"
    STATUS_PREFIX = "dobar:payments:status:"
    
    def __init__(self, redis_url: Optional[str] = None):
        self._redis_url = redis_url or os.getenv("REDIS_URL", "redis://localhost:6379")
        self._redis: Optional["aioredis.Redis"] = None
        self._callbacks: Dict[str, Callable] = {}
    
    async def connect(self) -> None:
        if not REDIS_AVAILABLE:
            raise RuntimeError("redis package not installed")
        self._redis = aioredis.from_url(self._redis_url, decode_responses=True)
        try:
            await self._redis.xgroup_create(self.STREAM_KEY, self.CONSUMER_GROUP, mkstream=True)
        except Exception:
            pass
    
    async def disconnect(self) -> None:
        if self._redis:
            await self._redis.close()
    
    async def enqueue(self, operation: str, payload: Dict[str, Any], max_attempts: int = 3) -> Job:
        job = Job(
            id=str(uuid.uuid4()),
            operation=operation,
            payload=payload,
            max_attempts=max_attempts,
        )
        await self._redis.xadd(self.STREAM_KEY, job.to_dict())
        await self._set_status(job)
        return job
    
    async def _set_status(self, job: Job) -> None:
        key = f"{self.STATUS_PREFIX}{job.id}"
        await self._redis.hset(key, mapping=job.to_dict())
        await self._redis.expire(key, 86400 * 7)
    
    async def get_status(self, job_id: str) -> Optional[Job]:
        key = f"{self.STATUS_PREFIX}{job_id}"
        data = await self._redis.hgetall(key)
        if not data:
            return None
        return Job.from_dict(data)
    
    async def update_status(self, job: Job) -> None:
        job.updated_at = datetime.now(timezone.utc)
        await self._set_status(job)
    
    async def consume(self, consumer_name: str, count: int = 1, block_ms: int = 5000) -> List[tuple]:
        messages = await self._redis.xreadgroup(
            self.CONSUMER_GROUP,
            consumer_name,
            {self.STREAM_KEY: ">"},
            count=count,
            block=block_ms,
        )
        if not messages:
            return []
        jobs = []
        for stream, entries in messages:
            for msg_id, data in entries:
                job = Job.from_dict(data)
                jobs.append((msg_id, job))
        return jobs
    
    async def ack(self, message_id: str) -> None:
        await self._redis.xack(self.STREAM_KEY, self.CONSUMER_GROUP, message_id)
    
    async def pending_count(self) -> int:
        info = await self._redis.xpending(self.STREAM_KEY, self.CONSUMER_GROUP)
        return info.get("pending", 0) if info else 0


class InMemoryJobQueue:
    def __init__(self):
        self._jobs: Dict[str, Job] = {}
        self._queue: asyncio.Queue = asyncio.Queue()
    
    async def connect(self) -> None:
        pass
    
    async def disconnect(self) -> None:
        pass
    
    async def enqueue(self, operation: str, payload: Dict[str, Any], max_attempts: int = 3) -> Job:
        job = Job(
            id=str(uuid.uuid4()),
            operation=operation,
            payload=payload,
            max_attempts=max_attempts,
        )
        self._jobs[job.id] = job
        await self._queue.put(job.id)
        return job
    
    async def get_status(self, job_id: str) -> Optional[Job]:
        return self._jobs.get(job_id)
    
    async def update_status(self, job: Job) -> None:
        job.updated_at = datetime.now(timezone.utc)
        self._jobs[job.id] = job
    
    async def consume(self, consumer_name: str, count: int = 1, block_ms: int = 5000) -> List[tuple]:
        try:
            job_id = await asyncio.wait_for(self._queue.get(), timeout=block_ms / 1000)
            job = self._jobs.get(job_id)
            if job:
                return [(job_id, job)]
        except asyncio.TimeoutError:
            pass
        return []
    
    async def ack(self, message_id: str) -> None:
        pass
    
    async def pending_count(self) -> int:
        return self._queue.qsize()


def get_job_queue(use_redis: bool = True) -> RedisJobQueue | InMemoryJobQueue:
    if use_redis and REDIS_AVAILABLE:
        return RedisJobQueue()
    return InMemoryJobQueue()
