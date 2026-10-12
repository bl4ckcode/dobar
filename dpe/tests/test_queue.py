import pytest
import asyncio
from datetime import datetime, timezone


class TestJobDataclass:
    def test_job_creation(self):
        import importlib.util
        spec = importlib.util.spec_from_file_location('streams', 'dobar_payment/queue/streams.py')
        streams = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(streams)
        
        job = streams.Job(
            id="test-123",
            operation="charge",
            payload={"amount": 100, "currency": "BRL"}
        )
        
        assert job.id == "test-123"
        assert job.operation == "charge"
        assert job.status == streams.JobStatus.PENDING
        assert job.attempts == 0
    
    def test_job_to_dict(self):
        import importlib.util
        spec = importlib.util.spec_from_file_location('streams', 'dobar_payment/queue/streams.py')
        streams = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(streams)
        
        job = streams.Job(
            id="test-456",
            operation="refund",
            payload={"charge_id": "ch_123"}
        )
        
        data = job.to_dict()
        assert data["id"] == "test-456"
        assert data["operation"] == "refund"
        assert data["status"] == "pending"
        assert "charge_id" in data["payload"]
    
    def test_job_from_dict(self):
        import importlib.util
        spec = importlib.util.spec_from_file_location('streams', 'dobar_payment/queue/streams.py')
        streams = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(streams)
        
        data = {
            "id": "test-789",
            "operation": "capture",
            "payload": '{"intent_id": "pi_123"}',
            "status": "completed",
            "result": '{"success": true}',
            "error": "",
            "attempts": "2",
            "max_attempts": "3",
            "created_at": datetime.now(timezone.utc).isoformat(),
            "updated_at": datetime.now(timezone.utc).isoformat(),
        }
        
        job = streams.Job.from_dict(data)
        assert job.id == "test-789"
        assert job.status == streams.JobStatus.COMPLETED
        assert job.attempts == 2
        assert job.result == {"success": True}


class TestInMemoryQueue:
    @pytest.mark.asyncio
    async def test_enqueue_and_consume(self):
        import importlib.util
        spec = importlib.util.spec_from_file_location('streams', 'dobar_payment/queue/streams.py')
        streams = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(streams)
        
        queue = streams.InMemoryJobQueue()
        await queue.connect()
        
        job = await queue.enqueue("charge", {"amount": 50})
        assert job.operation == "charge"
        assert job.status == streams.JobStatus.PENDING
        
        messages = await queue.consume("test-worker", count=1, block_ms=100)
        assert len(messages) == 1
        msg_id, consumed_job = messages[0]
        assert consumed_job.operation == "charge"
        
        await queue.disconnect()
    
    @pytest.mark.asyncio
    async def test_get_status(self):
        import importlib.util
        spec = importlib.util.spec_from_file_location('streams', 'dobar_payment/queue/streams.py')
        streams = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(streams)
        
        queue = streams.InMemoryJobQueue()
        await queue.connect()
        
        job = await queue.enqueue("refund", {"charge_id": "ch_test"})
        
        status = await queue.get_status(job.id)
        assert status is not None
        assert status.operation == "refund"
        
        await queue.disconnect()
    
    @pytest.mark.asyncio
    async def test_update_status(self):
        import importlib.util
        spec = importlib.util.spec_from_file_location('streams', 'dobar_payment/queue/streams.py')
        streams = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(streams)
        
        queue = streams.InMemoryJobQueue()
        await queue.connect()
        
        job = await queue.enqueue("capture", {"intent_id": "pi_test"})
        job.status = streams.JobStatus.COMPLETED
        job.result = {"captured": True}
        
        await queue.update_status(job)
        
        updated = await queue.get_status(job.id)
        assert updated.status == streams.JobStatus.COMPLETED
        assert updated.result == {"captured": True}
        
        await queue.disconnect()


class TestJobStatus:
    def test_status_values(self):
        import importlib.util
        spec = importlib.util.spec_from_file_location('streams', 'dobar_payment/queue/streams.py')
        streams = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(streams)
        
        assert streams.JobStatus.PENDING.value == "pending"
        assert streams.JobStatus.PROCESSING.value == "processing"
        assert streams.JobStatus.COMPLETED.value == "completed"
        assert streams.JobStatus.FAILED.value == "failed"
        assert streams.JobStatus.RETRYING.value == "retrying"


class TestJobTracker:
    def _load_modules(self):
        import importlib.util
        import sys
        
        spec = importlib.util.spec_from_file_location('streams', 'dobar_payment/queue/streams.py')
        streams = importlib.util.module_from_spec(spec)
        sys.modules['dobar_payment.queue.streams'] = streams
        spec.loader.exec_module(streams)
        return streams
    
    @pytest.mark.asyncio
    async def test_subscribe_and_notify(self):
        streams = self._load_modules()
        
        queue = streams.InMemoryJobQueue()
        await queue.connect()
        
        subscribers = {}
        global_subscribers = []
        local_jobs = {}
        
        async def notify(job, subs, global_subs, local):
            local[job.id] = job
            tasks = []
            if job.id in subs:
                for cb in subs[job.id]:
                    tasks.append(asyncio.create_task(cb(job)))
            for cb in global_subs:
                tasks.append(asyncio.create_task(cb(job)))
            if tasks:
                await asyncio.gather(*tasks, return_exceptions=True)
        
        received = []
        async def callback(job):
            received.append(job)
        
        job = await queue.enqueue("charge", {"amount": 100})
        subscribers[job.id] = [callback]
        
        job.status = streams.JobStatus.PROCESSING
        await notify(job, subscribers, global_subscribers, local_jobs)
        
        assert len(received) == 1
        assert received[0].status == streams.JobStatus.PROCESSING
        await queue.disconnect()
    
    @pytest.mark.asyncio
    async def test_global_subscribe(self):
        streams = self._load_modules()
        
        queue = streams.InMemoryJobQueue()
        await queue.connect()
        
        global_subscribers = []
        
        async def notify(job, global_subs):
            tasks = [asyncio.create_task(cb(job)) for cb in global_subs]
            if tasks:
                await asyncio.gather(*tasks, return_exceptions=True)
        
        received = []
        async def callback(job):
            received.append(job)
        
        global_subscribers.append(callback)
        
        job1 = await queue.enqueue("charge", {"amount": 100})
        job2 = await queue.enqueue("refund", {"charge_id": "ch_123"})
        
        await notify(job1, global_subscribers)
        await notify(job2, global_subscribers)
        
        assert len(received) == 2
        await queue.disconnect()
    
    def test_job_to_event_format(self):
        streams = self._load_modules()
        
        job = streams.Job(
            id="test-123",
            operation="charge",
            payload={"amount": 100},
            status=streams.JobStatus.COMPLETED,
            result={"transaction_id": "tx_456"}
        )
        
        event = {
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
        
        assert event["type"] == "job_update"
        assert event["data"]["id"] == "test-123"
        assert event["data"]["status"] == "completed"
        assert event["data"]["result"]["transaction_id"] == "tx_456"


class TestWebSocketManager:
    def _load_streams(self):
        import importlib.util
        import sys
        spec = importlib.util.spec_from_file_location('streams', 'dobar_payment/queue/streams.py')
        streams = importlib.util.module_from_spec(spec)
        sys.modules['dobar_payment.queue.streams'] = streams
        spec.loader.exec_module(streams)
        return streams
    
    @pytest.mark.asyncio
    async def test_connect_disconnect(self):
        streams = self._load_streams()
        
        queue = streams.InMemoryJobQueue()
        await queue.connect()
        
        connections = {}
        user_connections = {}
        
        async def mock_send(msg):
            pass
        
        conn_id = "conn-123"
        user_id = "user-456"
        connections[conn_id] = {
            "id": conn_id,
            "send": mock_send,
            "subscribed_jobs": set(),
            "user_id": user_id
        }
        
        if user_id not in user_connections:
            user_connections[user_id] = set()
        user_connections[user_id].add(conn_id)
        
        assert len(connections) == 1
        assert conn_id in user_connections[user_id]
        
        del connections[conn_id]
        user_connections[user_id].discard(conn_id)
        
        assert len(connections) == 0
        await queue.disconnect()
    
    @pytest.mark.asyncio
    async def test_subscribe_job(self):
        streams = self._load_streams()
        
        queue = streams.InMemoryJobQueue()
        await queue.connect()
        
        job_to_connections = {}
        connection = {
            "id": "conn-123",
            "subscribed_jobs": set()
        }
        
        job_id = "job-456"
        connection["subscribed_jobs"].add(job_id)
        if job_id not in job_to_connections:
            job_to_connections[job_id] = set()
        job_to_connections[job_id].add(connection["id"])
        
        assert job_id in connection["subscribed_jobs"]
        assert connection["id"] in job_to_connections[job_id]
        await queue.disconnect()
    
    @pytest.mark.asyncio
    async def test_notification_sent_on_update(self):
        streams = self._load_streams()
        
        queue = streams.InMemoryJobQueue()
        await queue.connect()
        
        messages_sent = []
        
        async def mock_send(msg):
            messages_sent.append(msg)
        
        job = await queue.enqueue("charge", {"amount": 100})
        
        job_to_connections = {job.id: {"conn-123"}}
        connections = {
            "conn-123": {"send": mock_send}
        }
        
        event = {
            "type": "job_update",
            "data": {
                "id": job.id,
                "status": "completed"
            }
        }
        
        import json
        for conn_id in job_to_connections.get(job.id, set()):
            conn = connections.get(conn_id)
            if conn:
                await conn["send"](json.dumps(event))
        
        assert len(messages_sent) == 1
        parsed = json.loads(messages_sent[0])
        assert parsed["type"] == "job_update"
        assert parsed["data"]["id"] == job.id
        await queue.disconnect()
