from typing import Dict, Any, Set, Optional, Callable, Awaitable
from dataclasses import dataclass
import asyncio
import json
import logging

from .streams import Job, JobStatus
from .tracker import JobTracker

logger = logging.getLogger("dobar.payment.websocket")

WebSocketSend = Callable[[str], Awaitable[None]]


@dataclass
class WebSocketConnection:
    id: str
    send: WebSocketSend
    subscribed_jobs: Set[str]
    user_id: Optional[str] = None


class WebSocketManager:
    def __init__(self, tracker: JobTracker):
        self._tracker = tracker
        self._connections: Dict[str, WebSocketConnection] = {}
        self._job_to_connections: Dict[str, Set[str]] = {}
        self._user_connections: Dict[str, Set[str]] = {}
        self._tracker.subscribe_all(self._on_job_update)
    
    async def connect(
        self, 
        connection_id: str, 
        send_func: WebSocketSend,
        user_id: Optional[str] = None
    ) -> None:
        conn = WebSocketConnection(
            id=connection_id,
            send=send_func,
            subscribed_jobs=set(),
            user_id=user_id,
        )
        self._connections[connection_id] = conn
        if user_id:
            if user_id not in self._user_connections:
                self._user_connections[user_id] = set()
            self._user_connections[user_id].add(connection_id)
        logger.debug(f"WebSocket connected: {connection_id}")
    
    def disconnect(self, connection_id: str) -> None:
        conn = self._connections.pop(connection_id, None)
        if not conn:
            return
        for job_id in conn.subscribed_jobs:
            if job_id in self._job_to_connections:
                self._job_to_connections[job_id].discard(connection_id)
        if conn.user_id and conn.user_id in self._user_connections:
            self._user_connections[conn.user_id].discard(connection_id)
        logger.debug(f"WebSocket disconnected: {connection_id}")
    
    def subscribe_job(self, connection_id: str, job_id: str) -> None:
        conn = self._connections.get(connection_id)
        if not conn:
            return
        conn.subscribed_jobs.add(job_id)
        if job_id not in self._job_to_connections:
            self._job_to_connections[job_id] = set()
        self._job_to_connections[job_id].add(connection_id)
    
    def unsubscribe_job(self, connection_id: str, job_id: str) -> None:
        conn = self._connections.get(connection_id)
        if not conn:
            return
        conn.subscribed_jobs.discard(job_id)
        if job_id in self._job_to_connections:
            self._job_to_connections[job_id].discard(connection_id)
    
    async def _on_job_update(self, job: Job) -> None:
        connection_ids = self._job_to_connections.get(job.id, set())
        if not connection_ids:
            return
        event = self._tracker.job_to_event(job)
        message = json.dumps(event)
        tasks = []
        for conn_id in list(connection_ids):
            conn = self._connections.get(conn_id)
            if conn:
                tasks.append(self._safe_send(conn, message))
        if tasks:
            await asyncio.gather(*tasks, return_exceptions=True)
        if job.status in (JobStatus.COMPLETED, JobStatus.FAILED):
            for conn_id in list(connection_ids):
                self.unsubscribe_job(conn_id, job.id)
    
    async def _safe_send(self, conn: WebSocketConnection, message: str) -> None:
        try:
            await conn.send(message)
        except Exception as e:
            logger.warning(f"Failed to send to {conn.id}: {e}")
            self.disconnect(conn.id)
    
    async def broadcast_to_user(self, user_id: str, message: Dict[str, Any]) -> None:
        conn_ids = self._user_connections.get(user_id, set())
        if not conn_ids:
            return
        json_message = json.dumps(message)
        tasks = []
        for conn_id in list(conn_ids):
            conn = self._connections.get(conn_id)
            if conn:
                tasks.append(self._safe_send(conn, json_message))
        if tasks:
            await asyncio.gather(*tasks, return_exceptions=True)
    
    @property
    def connection_count(self) -> int:
        return len(self._connections)
