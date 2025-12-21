#!/bin/bash

set -euo pipefail

TARGET_URL="${TARGET_URL:-http://app:3000}"
OUTPUT_DIR="${OUTPUT_DIR:-/app/reports}"

mkdir -p "${OUTPUT_DIR}"

echo "Starting stress test with k6…"
echo "Target: ${TARGET_URL}"

# Stress test configuration
cat > /tmp/stress-test.js <<'EOF'
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '2m', target: 100 },   // Below normal load
    { duration: '5m', target: 100 },   // Stay at normal load
    { duration: '2m', target: 200 },   // Around breaking point
    { duration: '5m', target: 200 },   // Stay at breaking point
    { duration: '2m', target: 300 },   // Beyond breaking point
    { duration: '5m', target: 300 },   // Stay beyond breaking point
    { duration: '10m', target: 0 },    // Scale down (recovery stage)
  ],
  thresholds: {
    http_req_duration: ['p(99)<1000'],
  },
};

const TARGET_URL = __ENV.TARGET_URL || 'http://app:3000';

export default function () {
  const res = http.get(TARGET_URL);

  check(res, {
    'status is 200': (r) => r.status === 200,
  });

  sleep(1);
}
EOF

k6 run \
  --env TARGET_URL="${TARGET_URL}" \
  --out json="${OUTPUT_DIR}/stress-test-results.json" \
  /tmp/stress-test.js

echo "Stress test completed!"
echo "Results: ${OUTPUT_DIR}/stress-test-results.json"
