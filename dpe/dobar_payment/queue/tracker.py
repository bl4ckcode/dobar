from typing import Dict, Any, Optional, Callable, Awaitable, List
from dataclasses import dataclass, field
from datetime import datetime, timezone
import asyncio
import json

from .streams import Job, JobStatus, RedisJobQueue, InMemoryJobQueue


StatusCallback = Callable[[Job], Awaitable[None]]


@dataclass
class JobProgress:
    job_id: str
    status: JobStatus
    progress_pct: int = 0
    message: str = ""
    created_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))


class JobTracker:
    PUBSUB_CHANNEL = "dobar:payments:job-updates"
    
    def __init__(self, queue: RedisJobQueue | InMemoryJobQueue):
        self._queue = queue
        self._subscribers: Dict[str, List[StatusCallback]] = {}
        self._global_subscribers: List[StatusCallback] = []
        self._local_jobs: Dict[str, Job] = {}
    
    async def get_job(self, job_id: str) -> Optional[Job]:
        return await self._queue.get_status(job_id)
    
    async def get_jobs_by_status(self, status: JobStatus, limit: int = 100) -> List[Job]:
        if isinstance(self._queue, InMemoryJobQueue):
            return [
                j for j in self._queue._jobs.values() 
                if j.status == status
            ][:limit]
        return []
    
    async def get_recent_jobs(self, limit: int = 50) -> List[Job]:
        if isinstance(self._queue, InMemoryJobQueue):
            jobs = sorted(
                self._queue._jobs.values(),
                key=lambda j: j.created_at,
                reverse=True
            )
            return jobs[:limit]
        return []
    
    def subscribe(self, job_id: str, callback: StatusCallback) -> Callable[[], None]:
        if job_id not in self._subscribers:
            self._subscribers[job_id] = []
        self._subscribers[job_id].append(callback)
        
        def unsubscribe():
            if job_id in self._subscribers:
                self._subscribers[job_id].remove(callback)
        return unsubscribe
    
    def subscribe_all(self, callback: StatusCallback) -> Callable[[], None]:
        self._global_subscribers.append(callback)
        
        def unsubscribe():
            self._global_subscribers.remove(callback)
        return unsubscribe
    
    async def notify(self, job: Job) -> None:
        self._local_jobs[job.id] = job
        
        tasks = []
        if job.id in self._subscribers:
            for cb in self._subscribers[job.id]:
                tasks.append(asyncio.create_task(self._safe_callback(cb, job)))
        
        for cb in self._global_subscribers:
            tasks.append(asyncio.create_task(self._safe_callback(cb, job)))
        
        if tasks:
            await asyncio.gather(*tasks, return_exceptions=True)
        
        if job.status in (JobStatus.COMPLETED, JobStatus.FAILED):
            self._subscribers.pop(job.id, None)
    
    async def _safe_callback(self, callback: StatusCallback, job: Job) -> None:
        try:
            await callback(job)
        except Exception:
            pass
    
    async def wait_for_completion(
        self, 
        job_id: str, 
        timeout: float = 30.0,
        poll_interval: float = 0.5
    ) -> Job:
        deadline = asyncio.get_event_loop().time() + timeout
        while asyncio.get_event_loop().time() < deadline:
            job = await self.get_job(job_id)
            if job and job.status in (JobStatus.COMPLETED, JobStatus.FAILED):
                return job
            await asyncio.sleep(poll_interval)
        job = await self.get_job(job_id)
        if job:
            return job
        raise TimeoutError(f"Job {job_id} did not complete within {timeout}s")
    
    def job_to_event(self, job: Job) -> Dict[str, Any]:
        return {
            "type": "job_update",
            "data": {
                "id": job.id,
                "operation": job.operation,
                "status": job.status.value,
                "result": job.result,
                "error": job.error,
                "attempts": job.attempts,
                "created_at": job.created_at.isoformat(),
                "updated_at": job.updated_at.isoformat(),
            }
        }


class TrackedWorkerMixin:
    _tracker: Optional[JobTracker] = None
    
    def set_tracker(self, tracker: JobTracker) -> None:
        self._tracker = tracker
    
    async def _notify_status(self, job: Job) -> None:
        if self._tracker:
            await self._tracker.notify(job)
