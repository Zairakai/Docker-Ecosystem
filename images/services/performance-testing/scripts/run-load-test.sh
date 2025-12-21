#!/bin/bash

set -euo pipefail

TARGET_URL="${TARGET_URL:-http://app:3000}"
TEST_TYPE="${TEST_TYPE:-artillery}"
OUTPUT_DIR="${OUTPUT_DIR:-/app/reports}"

mkdir -p "${OUTPUT_DIR}"

echo "Starting load test…"
echo "Target: ${TARGET_URL}"
echo "Tool: ${TEST_TYPE}"

case "${TEST_TYPE}" in
  artillery)
    echo "Running Artillery load test…"
    artillery run \
      --target "${TARGET_URL}" \
      --output "${OUTPUT_DIR}/artillery-report.json" \
      /app/config/artillery.yml

    artillery report \
      "${OUTPUT_DIR}/artillery-report.json" \
      --output "${OUTPUT_DIR}/artillery-report.html"

    echo "Artillery report: ${OUTPUT_DIR}/artillery-report.html"
    ;;

  k6)
    echo "Running k6 load test…"
    k6 run \
      --env TARGET_URL="${TARGET_URL}" \
      --out json="${OUTPUT_DIR}/k6-results.json" \
      /app/config/k6-config.js

    echo "k6 results: ${OUTPUT_DIR}/k6-results.json"
    ;;

  autocannon)
    echo "Running autocannon load test…"
    autocannon \
      --connections 100 \
      --duration 60 \
      --json \
      "${TARGET_URL}" > "${OUTPUT_DIR}/autocannon-results.json"

    echo "Autocannon results: ${OUTPUT_DIR}/autocannon-results.json"
    ;;

  locust)
    echo "Running Locust load test…"
    locust \
      --host="${TARGET_URL}" \
      --users=100 \
      --spawn-rate=10 \
      --run-time=120s \
      --headless \
      --html="${OUTPUT_DIR}/locust-report.html"

    echo "Locust report: ${OUTPUT_DIR}/locust-report.html"
    ;;

  *)
    echo "Unknown test type: ${TEST_TYPE}"
    echo "Available types: artillery, k6, autocannon, locust"
    exit 1
    ;;
esac

echo "Load test completed successfully!"
