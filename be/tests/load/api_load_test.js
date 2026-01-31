import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Rate, Trend } from 'k6/metrics';

const errorRate = new Rate('errors');
const orderDuration = new Trend('order_duration');

export const options = {
    stages: [
        { duration: '1m', target: 50 },
        { duration: '3m', target: 200 },
        { duration: '5m', target: 500 },
        { duration: '3m', target: 1000 },
        { duration: '2m', target: 0 },
    ],
    thresholds: {
        http_req_duration: ['p(95)<500', 'p(99)<1000'],
        http_req_failed: ['rate<0.01'],
        errors: ['rate<0.05'],
    },
};

const API_URL = __ENV.API_URL || 'https://barz-backend-bold-sun-5691.fly.dev';
const TEST_TOKEN = __ENV.TEST_TOKEN || '';

const headers = {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${TEST_TOKEN}`,
};

export default function () {
    group('Health Check', function () {
        const health = http.get(`${API_URL}/health`);
        check(health, {
            'health status 200': (r) => r.status === 200,
            'health response time < 100ms': (r) => r.timings.duration < 100,
        }) || errorRate.add(1);
    });

    group('List Bars', function () {
        const bars = http.get(`${API_URL}/api/v1/bars?lat=-23.5505&lon=-46.6333&radius=5000`);
        check(bars, {
            'bars status 200': (r) => r.status === 200,
            'bars response time < 500ms': (r) => r.timings.duration < 500,
        }) || errorRate.add(1);

        if (bars.status === 200) {
            const barList = JSON.parse(bars.body);
            if (barList.length > 0) {
                const barId = barList[0].id;

                group('Get Menu', function () {
                    const menu = http.get(`${API_URL}/api/v1/bars/${barId}/menu`);
                    check(menu, {
                        'menu status 200': (r) => r.status === 200,
                        'menu response time < 300ms': (r) => r.timings.duration < 300,
                    }) || errorRate.add(1);
                });
            }
        }
    });

    sleep(Math.random() * 2 + 1);
}

export function handleSummary(data) {
    return {
        'stdout': textSummary(data, { indent: ' ', enableColors: true }),
        'summary.json': JSON.stringify(data),
    };
}

function textSummary(data, opts) {
    const indent = opts.indent || '';
    let result = '\n' + indent + '=== LOAD TEST RESULTS ===\n\n';
    
    result += indent + `Total Requests: ${data.metrics.http_reqs.values.count}\n`;
    result += indent + `Failed Requests: ${data.metrics.http_req_failed.values.passes}\n`;
    result += indent + `Avg Duration: ${data.metrics.http_req_duration.values.avg.toFixed(2)}ms\n`;
    result += indent + `p95 Duration: ${data.metrics.http_req_duration.values['p(95)'].toFixed(2)}ms\n`;
    result += indent + `p99 Duration: ${data.metrics.http_req_duration.values['p(99)'].toFixed(2)}ms\n`;
    
    return result;
}
