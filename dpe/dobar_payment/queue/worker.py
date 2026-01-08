from typing import Dict, Any, Optional, Callable, Awaitable
import asyncio
import logging
import signal
import os

from .streams import Job, JobStatus, RedisJobQueue, InMemoryJobQueue, get_job_queue
from .tracker import JobTracker

logger = logging.getLogger("dobar.payment.worker")

OperationHandler = Callable[[Dict[str, Any]], Awaitable[Dict[str, Any]]]


class PaymentWorker:
    def __init__(
        self,
        queue: Optional[RedisJobQueue | InMemoryJobQueue] = None,
        consumer_name: Optional[str] = None,
        concurrency: int = 10,
        tracker: Optional[JobTracker] = None,
    ):
        self._queue = queue or get_job_queue()
        self._consumer_name = consumer_name or f"worker-{os.getpid()}"
        self._concurrency = concurrency
        self._handlers: Dict[str, OperationHandler] = {}
        self._running = False
        self._tasks: set = set()
        self._tracker = tracker
    
    def set_tracker(self, tracker: JobTracker) -> None:
        self._tracker = tracker
    
    def register(self, operation: str, handler: OperationHandler) -> None:
        self._handlers[operation] = handler
    
    async def _notify(self, job: Job) -> None:
        if self._tracker:
            await self._tracker.notify(job)
    
    async def _process_job(self, msg_id: str, job: Job) -> None:
        handler = self._handlers.get(job.operation)
        if not handler:
            logger.warning(f"No handler for operation: {job.operation}")
            job.status = JobStatus.FAILED
            job.error = f"Unknown operation: {job.operation}"
            await self._queue.update_status(job)
            await self._notify(job)
            await self._queue.ack(msg_id)
            return
        
        job.status = JobStatus.PROCESSING
        job.attempts += 1
        await self._queue.update_status(job)
        await self._notify(job)
        
        try:
            result = await handler(job.payload)
            job.status = JobStatus.COMPLETED
            job.result = result
            logger.info(f"Job {job.id} completed")
        except Exception as e:
            logger.exception(f"Job {job.id} failed: {e}")
            if job.attempts < job.max_attempts:
                job.status = JobStatus.RETRYING
                job.error = str(e)
                await self._queue.enqueue(job.operation, job.payload, job.max_attempts)
            else:
                job.status = JobStatus.FAILED
                job.error = str(e)
        
        await self._queue.update_status(job)
        await self._notify(job)
        await self._queue.ack(msg_id)
    
    async def _worker_loop(self) -> None:
        while self._running:
            try:
                messages = await self._queue.consume(self._consumer_name, count=1, block_ms=1000)
                for msg_id, job in messages:
                    if len(self._tasks) >= self._concurrency:
                        done, self._tasks = await asyncio.wait(self._tasks, return_when=asyncio.FIRST_COMPLETED)
                    task = asyncio.create_task(self._process_job(msg_id, job))
                    self._tasks.add(task)
            except asyncio.CancelledError:
                break
            except Exception as e:
                logger.exception(f"Worker error: {e}")
                await asyncio.sleep(1)
    
    async def start(self) -> None:
        await self._queue.connect()
        self._running = True
        logger.info(f"Worker {self._consumer_name} started")
        await self._worker_loop()
    
    async def stop(self) -> None:
        self._running = False
        if self._tasks:
            await asyncio.gather(*self._tasks, return_exceptions=True)
        await self._queue.disconnect()
        logger.info(f"Worker {self._consumer_name} stopped")
    
    def run(self) -> None:
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        
        def shutdown():
            self._running = False
        
        loop.add_signal_handler(signal.SIGTERM, shutdown)
        loop.add_signal_handler(signal.SIGINT, shutdown)
        
        try:
            loop.run_until_complete(self.start())
        finally:
            loop.run_until_complete(self.stop())
            loop.close()
