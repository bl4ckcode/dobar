# SCALABILITY ASSESSMENT: DOBAR ECOSYSTEM

> **Version:** 1.0  
> **Date:** January 2026  
> **Purpose:** AI-Consumable Technical Assessment  
> **Format:** Structured for Agent Processing

---

## METADATA

```yaml
document_type: scalability_assessment
target_scale: 1000-100000 concurrent_users
priority: high
last_review: 2026-01-26
next_review: 2026-04-26
repositories:
  - name: barz-backend
    path: /Users/carlosalves/Documents/PDev/barz-backend
    type: fastapi
  - name: dobar-payment-engine
    path: /Users/carlosalves/Documents/PDev/dobar-payment-engine
    type: fastapi
  - name: barz
    path: /Users/carlosalves/Documents/PDev/barz
    type: flutter
```

---

## EXECUTIVE SUMMARY

| Dimension | Current State | Target State | Status |
|-----------|---------------|--------------|--------|
| Concurrent Users | ~100-500 | 10,000-100,000 | 🟡 In Progress |
| Transaction Throughput | ~10 TPS | 1,000+ TPS | 🟡 In Progress |
| Connection Pooling | QueuePool configured | PgBouncer/Pooled | ✅ Completed |
| Caching | CacheService ready | Redis Layer | ✅ Completed |
| Message Queue | Redis Streams | Redis Streams | ✅ Completed |
| Rate Limiting | Slowapi + Redis | Distributed | ✅ Completed |
| Load Testing | k6 scripts | Automated | ✅ Completed |
| Offline Support | Partial | Full Queue | 🟢 Pending (Flutter) |
| Monitoring | /metrics endpoint | Full Observability | ✅ Completed |
| WebSocket Scaling | Redis Pub/Sub | Cross-instance | ✅ Completed |
| Horizontal Scaling | fly.toml configured | Auto-scaling | ✅ Completed |
| Read Replicas | Config ready | Provisioned | ⏸️ Deferred (cost) |

---

## IDENTIFIED GAPS

### GAP-001: Connection Pooling

```yaml
id: GAP-001
severity: critical
component: barz-backend
category: database
status: completed
effort: medium
implemented: 2026-01-27
files: app/database.py
```

**Current State:**
- Using default SQLAlchemy connection handling
- No external connection pooler
- Connection limit tied to Fly.io PostgreSQL defaults

**Problem:**
- At 1,000+ concurrent users, connection exhaustion occurs
- Each request creates new DB connection
- Fly.io Postgres has ~25-100 connection limit by default

**Solution:**

```python
# Option 1: Use Supabase/Neon Pooler (Recommended)
DATABASE_URL = "postgresql://user:pass@pooler.supabase.com:5432/db"

# Option 2: Configure PgBouncer sidecar on Fly.io
# fly.toml addition:
# [services.internal_port]
#   pgbouncer = 6432

# Option 3: SQLAlchemy pool configuration
from sqlalchemy.pool import QueuePool

engine = create_engine(
    DATABASE_URL,
    poolclass=QueuePool,
    pool_size=20,
    max_overflow=40,
    pool_pre_ping=True,
    pool_recycle=300,
)
```

**Files to Modify:**
- `barz-backend/app/core/database.py`
- `barz-backend/fly.toml`
- `dobar-payment-engine/dobar_payment/core/database.py`

**Verification:**
```bash
# Test connection count under load
psql -c "SELECT count(*) FROM pg_stat_activity WHERE datname='barz_db';"
```

---

### GAP-002: Caching Layer

```yaml
id: GAP-002
severity: high
component: barz-backend
category: performance
status: completed
effort: medium
implemented: 2026-01-27
files: app/redis_client.py
```

**Current State:**
- No caching layer implemented
- All requests hit database directly
- Menu and bar data fetched on every request

**Problem:**
- Database becomes bottleneck at scale
- Repeated queries for same data (menus, bars, categories)
- High latency during peak usage

**Solution:**

```python
# Add Redis caching with cachetools or redis-py

# 1. Install dependencies
# pip install redis aioredis

# 2. Create cache service
# barz-backend/app/core/cache.py

import redis.asyncio as redis
from functools import wraps
import json

redis_client = redis.from_url(os.getenv("REDIS_URL"))

async def get_cached(key: str, ttl: int, fetch_fn):
    cached = await redis_client.get(key)
    if cached:
        return json.loads(cached)
    
    data = await fetch_fn()
    await redis_client.setex(key, ttl, json.dumps(data))
    return data

# 3. Usage in routes
@router.get("/bars/{bar_id}/menu")
async def get_menu(bar_id: int):
    cache_key = f"menu:{bar_id}"
    return await get_cached(
        cache_key,
        ttl=300,  # 5 minutes
        fetch_fn=lambda: fetch_menu_from_db(bar_id)
    )
```

**Cache Strategy:**

| Data Type | TTL | Invalidation |
|-----------|-----|--------------|
| Bar Details | 5 min | On update |
| Menu Items | 5 min | On update |
| Categories | 1 hour | On admin change |
| User Session | 24 hours | On logout |
| Active Promotions | 1 min | On change |

**Infrastructure:**
- Add Upstash Redis on Fly.io (serverless, low cost)
- Or deploy Redis via `fly launch --image redis:alpine`

**Files to Create:**
- `barz-backend/app/core/cache.py`
- `barz-backend/app/services/cache_service.py`

---

### GAP-003: Message Queue for Orders

```yaml
id: GAP-003
severity: high
component: barz-backend
category: architecture
status: completed
effort: high
implemented: 2026-01-31
files: app/order_queue.py, app/order_worker.py, app/bars_and_restaurants/routes/orders.py
```

**Current State:**
- Orders processed synchronously
- Direct database writes on order creation
- No queue for payment processing

**Problem:**
- Burst traffic causes request timeouts
- No retry mechanism for failed payments
- Order processing blocks API response

**Solution:**

```python
# Implement Redis Streams for order queue

# 1. Order submission (producer)
# barz-backend/app/api/v1/orders.py

async def create_order(order_data: OrderCreate):
    order_id = str(uuid4())
    
    # Queue for async processing
    await redis_client.xadd(
        "orders:pending",
        {
            "order_id": order_id,
            "data": json.dumps(order_data.dict()),
            "timestamp": datetime.utcnow().isoformat()
        }
    )
    
    return {"order_id": order_id, "status": "queued"}

# 2. Order processor (consumer)
# barz-backend/app/workers/order_processor.py

async def process_orders():
    while True:
        messages = await redis_client.xread(
            {"orders:pending": "$"},
            count=10,
            block=5000
        )
        
        for stream, entries in messages:
            for entry_id, data in entries:
                await process_single_order(data)
                await redis_client.xack("orders:pending", "processors", entry_id)

# 3. Run as separate Fly.io process
# fly.toml
# [[processes]]
#   name = "order-worker"
#   cmd = "python -m app.workers.order_processor"
```

**Architecture:**

```
┌─────────┐     ┌─────────────┐     ┌──────────────┐     ┌──────────┐
│  API    │────▶│ Redis Queue │────▶│ Order Worker │────▶│ Database │
│ Server  │     │  (pending)  │     │  (consumer)  │     │          │
└─────────┘     └─────────────┘     └──────────────┘     └──────────┘
     │                                      │
     │          ┌─────────────┐             │
     └─────────▶│  WebSocket  │◀────────────┘
                │  (status)   │
                └─────────────┘
```

**Files to Create:**
- `barz-backend/app/workers/order_processor.py`
- `barz-backend/app/workers/payment_processor.py`
- `barz-backend/app/core/queue.py`

---

### GAP-004: Rate Limiting

```yaml
id: GAP-004
severity: medium
component: barz-backend
category: security
status: completed
effort: low
implemented: 2026-01-27
files: app/rate_limiter.py, app/main.py
```

**Current State:**
- No rate limiting implemented
- API vulnerable to abuse
- No protection against burst traffic

**Solution:**

```python
# Use slowapi for FastAPI rate limiting

# 1. Install: pip install slowapi

# 2. Configure in main.py
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

limiter = Limiter(
    key_func=get_remote_address,
    storage_uri=os.getenv("REDIS_URL")  # Distributed limiting
)

app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# 3. Apply to routes
@router.post("/orders")
@limiter.limit("30/minute")
async def create_order(request: Request, order: OrderCreate):
    pass

@router.get("/bars")
@limiter.limit("100/minute")
async def list_bars(request: Request):
    pass
```

**Rate Limit Tiers:**

| Endpoint Category | Limit | Notes |
|-------------------|-------|-------|
| Order Creation | 30/min per user | Prevent spam |
| Payment Submit | 10/min per user | Fraud prevention |
| Menu Fetch | 100/min per user | Standard usage |
| Search | 60/min per user | Allow exploration |
| Auth | 5/min per IP | Brute force protection |

**Files to Modify:**
- `barz-backend/app/main.py`
- `barz-backend/app/api/v1/*.py` (decorators)

---

### GAP-005: Load Testing Infrastructure

```yaml
id: GAP-005
severity: high
component: all
category: testing
status: completed
effort: medium
implemented: 2026-01-27
files: tests/load/api_load_test.js, tests/load/README.md
```

**Current State:**
- No load testing scripts
- Unknown breaking point
- No baseline performance metrics

**Solution:**

```python
# Create k6 load testing scripts

# barz-backend/tests/load/order_flow.js

import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
    stages: [
        { duration: '2m', target: 100 },   // Ramp to 100 users
        { duration: '5m', target: 1000 },  // Ramp to 1000 users
        { duration: '2m', target: 5000 },  // Ramp to 5000 users
        { duration: '5m', target: 5000 },  // Stay at 5000
        { duration: '2m', target: 0 },     // Ramp down
    ],
    thresholds: {
        http_req_duration: ['p(95)<500'],  // 95% under 500ms
        http_req_failed: ['rate<0.01'],    // Less than 1% failure
    },
};

export default function () {
    // 1. Get nearby bars
    let bars = http.get(`${__ENV.API_URL}/api/v1/bars?lat=-23.5&lon=-46.6`);
    check(bars, { 'bars status 200': (r) => r.status === 200 });
    
    // 2. Get menu
    let menu = http.get(`${__ENV.API_URL}/api/v1/bars/1/menu`);
    check(menu, { 'menu status 200': (r) => r.status === 200 });
    
    // 3. Create order
    let order = http.post(
        `${__ENV.API_URL}/api/v1/orders`,
        JSON.stringify({ bar_id: 1, items: [{ id: 1, quantity: 2 }] }),
        { headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${__ENV.TOKEN}` } }
    );
    check(order, { 'order status 201': (r) => r.status === 201 });
    
    sleep(1);
}
```

**Test Scenarios:**

| Scenario | Target Users | Duration | Purpose |
|----------|--------------|----------|---------|
| Baseline | 100 | 5 min | Establish metrics |
| Growth | 1,000 | 10 min | Normal operation |
| Peak | 5,000 | 15 min | Happy hour simulation |
| Event | 10,000 | 30 min | Event stress test |
| Extreme | 50,000 | 10 min | Find breaking point |

**Commands:**
```bash
# Install k6
brew install k6

# Run baseline test
k6 run --env API_URL=https://barz-backend.fly.dev tests/load/order_flow.js

# Run with specific VUs
k6 run --vus 1000 --duration 5m tests/load/order_flow.js
```

**Files to Create:**
- `barz-backend/tests/load/order_flow.js`
- `barz-backend/tests/load/payment_flow.js`
- `barz-backend/tests/load/websocket_test.js`
- `barz-backend/tests/load/README.md`

---

### GAP-006: Monitoring and Observability

```yaml
id: GAP-006
severity: high
component: all
category: operations
status: completed
effort: medium
implemented: 2026-01-27
files: app/main.py (/metrics endpoint)
```

**Current State:**
- Basic Fly.io metrics only
- No distributed tracing
- No custom business metrics

**Solution:**

```python
# Add OpenTelemetry + Prometheus metrics

# 1. Install dependencies
# pip install opentelemetry-api opentelemetry-sdk opentelemetry-instrumentation-fastapi prometheus-client

# 2. Configure in main.py
from prometheus_client import Counter, Histogram, generate_latest
from opentelemetry import trace
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor

# Metrics
orders_total = Counter('orders_total', 'Total orders', ['status', 'bar_id'])
order_duration = Histogram('order_duration_seconds', 'Order processing time')
active_connections = Gauge('websocket_connections', 'Active WebSocket connections')

# Instrument FastAPI
FastAPIInstrumentor.instrument_app(app)

# Metrics endpoint
@app.get("/metrics")
async def metrics():
    return Response(generate_latest(), media_type="text/plain")
```

**Key Metrics to Track:**

| Metric | Type | Labels | Purpose |
|--------|------|--------|---------|
| `orders_total` | Counter | status, bar_id | Order volume |
| `order_duration_seconds` | Histogram | - | Latency tracking |
| `payment_success_total` | Counter | gateway, status | Payment health |
| `websocket_connections` | Gauge | - | Real-time capacity |
| `db_query_duration` | Histogram | query_type | DB performance |
| `cache_hit_ratio` | Gauge | cache_name | Cache effectiveness |

**Monitoring Stack:**
1. **Fly.io Metrics** - Infrastructure (free)
2. **Prometheus** - Custom metrics collection
3. **Grafana Cloud** - Visualization (free tier: 10K series)
4. **Sentry** - Error tracking (free tier: 5K events/month)

---

### GAP-007: Horizontal Scaling Configuration

```yaml
id: GAP-007
severity: critical
component: barz-backend
category: infrastructure
status: completed
effort: medium
implemented: 2026-01-27
files: fly.toml
```

**Current State:**
- Single Fly.io machine
- No auto-scaling configured
- Manual scaling only

**Solution:**

```toml
# fly.toml - Auto-scaling configuration

[http_service]
  internal_port = 8080
  force_https = true
  auto_stop_machines = false  # Keep warm for events
  auto_start_machines = true
  min_machines_running = 2     # Always have 2 replicas

[http_service.concurrency]
  type = "connections"
  hard_limit = 250
  soft_limit = 200

[[http_service.checks]]
  interval = "10s"
  timeout = "2s"
  grace_period = "5s"
  method = "get"
  path = "/health"

[[vm]]
  size = "shared-cpu-2x"  # 2 CPU, 512MB
  memory = "1gb"          # Increase for scale

[metrics]
  port = 9091
  path = "/metrics"
```

**Scaling Strategy:**

| Load Level | Machines | VM Size | Est. Capacity |
|------------|----------|---------|---------------|
| Baseline | 2 | shared-cpu-1x | 500 users |
| Normal | 4 | shared-cpu-2x | 2,000 users |
| Peak | 8 | dedicated-cpu-2x | 8,000 users |
| Event | 20 | dedicated-cpu-4x | 50,000 users |

**Commands:**
```bash
# Scale manually for events
fly scale count 10 --region gru

# Set auto-scaling
fly scale vm shared-cpu-2x --memory 1024

# Check current scale
fly status
```

---

### GAP-008: WebSocket Scaling

```yaml
id: GAP-008
severity: high
component: barz-backend
category: real-time
status: completed
effort: high
implemented: 2026-01-27
files: app/bars_and_restaurants/services/connection_manager.py
```

**Current State:**
- In-memory WebSocket management
- No cross-instance pub/sub
- Connections lost on deploy

**Problem:**
- Multiple instances can't share WebSocket state
- User on machine A won't receive updates from machine B
- Scaling breaks real-time functionality

**Solution:**

```python
# Use Redis Pub/Sub for WebSocket broadcasting

# barz-backend/app/services/realtime_service.py

import redis.asyncio as redis

class RealtimeService:
    def __init__(self):
        self.redis = redis.from_url(os.getenv("REDIS_URL"))
        self.local_connections: dict[str, WebSocket] = {}
    
    async def subscribe(self, channel: str, websocket: WebSocket):
        self.local_connections[websocket.client.host] = websocket
        
        pubsub = self.redis.pubsub()
        await pubsub.subscribe(channel)
        
        async for message in pubsub.listen():
            if message["type"] == "message":
                await websocket.send_json(json.loads(message["data"]))
    
    async def broadcast(self, channel: str, data: dict):
        # Publish to Redis - all instances will receive
        await self.redis.publish(channel, json.dumps(data))
    
    async def notify_order_update(self, order_id: str, status: str):
        await self.broadcast(
            f"order:{order_id}",
            {"type": "order_update", "status": status}
        )
```

**Architecture:**

```
┌──────────────────────────────────────────────────────────┐
│                    REDIS PUB/SUB                          │
│  Channel: order:123  ──────────────────────────────────▶ │
└──────────────────────────────────────────────────────────┘
        ▲                    │                    │
        │              ┌─────▼─────┐        ┌─────▼─────┐
   [publish]           │ Machine A │        │ Machine B │
        │              │ WS Clients│        │ WS Clients│
┌───────┴────────┐     └───────────┘        └───────────┘
│ Order Worker   │            │                    │
│ (status update)│            ▼                    ▼
└────────────────┘      [User 1, 2]          [User 3, 4]
```

---

### GAP-009: Database Read Replicas

```yaml
id: GAP-009
severity: medium
component: infrastructure
category: database
status: deferred
effort: high
note: Requires Fly.io Postgres replica provisioning (additional cost)
```

**Current State:**
- Single PostgreSQL instance
- All reads/writes to primary
- Potential bottleneck at scale

**Solution:**

```python
# Configure read replica routing

# barz-backend/app/core/database.py

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

PRIMARY_URL = os.getenv("DATABASE_URL")
REPLICA_URL = os.getenv("DATABASE_REPLICA_URL", PRIMARY_URL)

primary_engine = create_engine(PRIMARY_URL)
replica_engine = create_engine(REPLICA_URL)

PrimarySession = sessionmaker(bind=primary_engine)
ReplicaSession = sessionmaker(bind=replica_engine)

def get_write_db():
    db = PrimarySession()
    try:
        yield db
    finally:
        db.close()

def get_read_db():
    db = ReplicaSession()
    try:
        yield db
    finally:
        db.close()

# Usage in routes
@router.get("/bars")
async def list_bars(db: Session = Depends(get_read_db)):  # Read from replica
    pass

@router.post("/orders")
async def create_order(db: Session = Depends(get_write_db)):  # Write to primary
    pass
```

**Fly.io Postgres Replica:**
```bash
# Create read replica
fly postgres create --name barzdb-replica --region gru

# Attach as replica
fly postgres attach barzdb-replica --app barz-backend --var DATABASE_REPLICA_URL
```

---

### GAP-010: Offline Transaction Queue

```yaml
id: GAP-010
severity: medium
component: barz (flutter)
category: resilience
status: open
effort: medium
```

**Current State:**
- App requires connectivity
- Orders fail without internet
- No local queue for sync

**Solution:**

```dart
// Flutter offline queue implementation

// lib/services/offline_queue.dart

class OfflineQueueService {
  final Box<Map> _queue;
  final ApiService _api;
  
  OfflineQueueService(this._queue, this._api);
  
  Future<void> queueOrder(OrderRequest order) async {
    if (await _hasConnectivity()) {
      await _api.createOrder(order);
    } else {
      await _queue.add({
        'type': 'order',
        'data': order.toJson(),
        'timestamp': DateTime.now().toIso8601String(),
        'retries': 0,
      });
    }
  }
  
  Future<void> syncPendingOrders() async {
    final pending = _queue.values.toList();
    
    for (final item in pending) {
      try {
        await _api.createOrder(OrderRequest.fromJson(item['data']));
        await _queue.delete(item.key);
      } catch (e) {
        item['retries']++;
        if (item['retries'] > 3) {
          // Mark as failed, notify user
          await _notifyFailedOrder(item);
        }
      }
    }
  }
}
```

---

## ACTION PLAN

### Phase 1: Foundation (Week 1-2)

| Task | Gap | Priority | Effort |
|------|-----|----------|--------|
| Configure connection pooling | GAP-001 | 🔴 Critical | 4h |
| Add Redis caching layer | GAP-002 | 🔴 Critical | 8h |
| Implement rate limiting | GAP-004 | 🟡 High | 4h |
| Set up basic monitoring | GAP-006 | 🟡 High | 4h |

### Phase 2: Scaling (Week 3-4)

| Task | Gap | Priority | Effort |
|------|-----|----------|--------|
| Implement message queue | GAP-003 | 🔴 Critical | 16h |
| Configure auto-scaling | GAP-007 | 🔴 Critical | 4h |
| Create load testing suite | GAP-005 | 🟡 High | 8h |

### Phase 3: Resilience (Week 5-6)

| Task | Gap | Priority | Effort |
|------|-----|----------|--------|
| WebSocket pub/sub scaling | GAP-008 | 🟡 High | 12h |
| Database read replicas | GAP-009 | 🟡 High | 8h |
| Offline queue (Flutter) | GAP-010 | 🟢 Medium | 8h |

---

## CAPACITY TARGETS

| Metric | Current | Phase 1 | Phase 2 | Phase 3 |
|--------|---------|---------|---------|---------|
| Concurrent Users | ~500 | 2,000 | 10,000 | 50,000 |
| Orders/Second | ~10 | 50 | 200 | 1,000 |
| API Latency (p95) | ~500ms | 200ms | 100ms | 50ms |
| DB Connections | 25 | 100 | 500 | 2,000 |
| WebSocket Connections | ~100 | 1,000 | 10,000 | 50,000 |

---

## COST PROJECTIONS

| Scale | Fly.io | Redis | Monitoring | Total/Month |
|-------|--------|-------|------------|-------------|
| Baseline (500 users) | $50 | $10 | $0 | $60 |
| Normal (2,000 users) | $150 | $30 | $0 | $180 |
| Peak (10,000 users) | $400 | $50 | $50 | $500 |
| Event (50,000 users) | $1,500 | $100 | $100 | $1,700 |

---

## VERIFICATION CHECKLIST

After implementing each gap, verify with:

```bash
# Connection pooling
psql -c "SELECT count(*) FROM pg_stat_activity;"

# Cache hit ratio
redis-cli INFO stats | grep keyspace_hits

# Rate limiting
hey -n 1000 -c 100 https://api.dobar.app/health

# Load test
k6 run tests/load/order_flow.js

# WebSocket scaling
wscat -c wss://api.dobar.app/ws/orders/test
```

---

*Document designed for AI agent consumption. Update after each implementation phase.*
