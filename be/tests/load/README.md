# Load Testing

This directory contains k6 load testing scripts for barz-backend.

## Prerequisites

```bash
# Install k6
brew install k6
```

## Running Tests

### Basic Load Test
```bash
k6 run tests/load/api_load_test.js
```

### With Custom API URL
```bash
k6 run --env API_URL=https://your-api.fly.dev tests/load/api_load_test.js
```

### With Authentication Token
```bash
k6 run --env API_URL=https://barz-backend-bold-sun-5691.fly.dev --env TEST_TOKEN=your_jwt_token tests/load/api_load_test.js
```

### Quick Smoke Test (50 VUs, 1 minute)
```bash
k6 run --vus 50 --duration 1m tests/load/api_load_test.js
```

### Stress Test (1000 VUs)
```bash
k6 run --vus 1000 --duration 5m tests/load/api_load_test.js
```

## Test Stages

Default test stages:
1. Ramp up to 50 users (1 min)
2. Ramp up to 200 users (3 min)
3. Ramp up to 500 users (5 min)
4. Ramp up to 1000 users (3 min)
5. Ramp down (2 min)

## Thresholds

- 95th percentile response time < 500ms
- 99th percentile response time < 1000ms
- Error rate < 1%
