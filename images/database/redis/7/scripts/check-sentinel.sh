#!/bin/bash
# ================================
# Redis Sentinel Health Check
# ================================
# Verifies Redis Sentinel configuration and status

set -e

echo "========================================="
echo "Redis Sentinel Status Check"
echo "========================================="

SENTINEL_HOST="${SENTINEL_HOST:-redis-sentinel-1}"
SENTINEL_PORT="${SENTINEL_PORT:-26379}"
MASTER_NAME="${MASTER_NAME:-mymaster}"

echo "Sentinel Host: ${SENTINEL_HOST}"
echo "Sentinel Port: ${SENTINEL_PORT}"
echo "Master Name: ${MASTER_NAME}"
echo ""

# Check if sentinel is running
if ! redis-cli -h "${SENTINEL_HOST}" -p "${SENTINEL_PORT}" ping >/dev/null 2>&1; then
  echo "❌ Sentinel is not responding"
  exit 1
fi

echo "✓ Sentinel is running"

# Get master info
echo ""
echo "Master Information:"
echo "-------------------"
redis-cli -h "${SENTINEL_HOST}" -p "${SENTINEL_PORT}" SENTINEL master "${MASTER_NAME}"

# Get slaves info
echo ""
echo "Slaves Information:"
echo "-------------------"
redis-cli -h "${SENTINEL_HOST}" -p "${SENTINEL_PORT}" SENTINEL slaves "${MASTER_NAME}"

# Get sentinels info
echo ""
echo "Sentinels Information:"
echo "----------------------"
redis-cli -h "${SENTINEL_HOST}" -p "${SENTINEL_PORT}" SENTINEL sentinels "${MASTER_NAME}"

# Check if master is reachable
MASTER_IP=$(redis-cli -h "${SENTINEL_HOST}" -p "${SENTINEL_PORT}" SENTINEL get-master-addr-by-name "${MASTER_NAME}" | head -n1)
MASTER_PORT=$(redis-cli -h "${SENTINEL_HOST}" -p "${SENTINEL_PORT}" SENTINEL get-master-addr-by-name "${MASTER_NAME}" | tail -n1)

echo ""
echo "Current Master: ${MASTER_IP}:${MASTER_PORT}"

if redis-cli -h "${MASTER_IP}" -p "${MASTER_PORT}" ping >/dev/null 2>&1; then
  echo "✓ Master is reachable"
else
  echo "❌ Master is not reachable"
  exit 1
fi

echo ""
echo "========================================="
echo "✅ Redis Sentinel is healthy"
echo "========================================="
