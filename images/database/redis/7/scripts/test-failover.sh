#!/bin/bash
# ================================
# Redis Sentinel Failover Test
# ================================
# Tests automatic failover by forcing a master down

set -e

SENTINEL_HOST="${SENTINEL_HOST:-redis-sentinel-1}"
SENTINEL_PORT="${SENTINEL_PORT:-26379}"
MASTER_NAME="${MASTER_NAME:-mymaster}"

echo "========================================="
echo "Redis Sentinel Failover Test"
echo "========================================="
echo ""
echo "⚠️  This will trigger a failover!"
echo "   Current master will be demoted to slave"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Aborted."
  exit 0
fi

# Get current master
echo ""
echo "Step 1: Getting current master…"
CURRENT_MASTER=$(redis-cli -h "${SENTINEL_HOST}" -p "${SENTINEL_PORT}" SENTINEL get-master-addr-by-name "${MASTER_NAME}" | head -n1)
CURRENT_PORT=$(redis-cli -h "${SENTINEL_HOST}" -p "${SENTINEL_PORT}" SENTINEL get-master-addr-by-name "${MASTER_NAME}" | tail -n1)

echo "Current Master: ${CURRENT_MASTER}:${CURRENT_PORT}"

# Force failover
echo ""
echo "Step 2: Forcing failover…"
redis-cli -h "${SENTINEL_HOST}" -p "${SENTINEL_PORT}" SENTINEL failover "${MASTER_NAME}"

echo "✓ Failover command sent"

# Wait for failover to complete
echo ""
echo "Step 3: Waiting for failover to complete (max 30s)…"
for _ in {1..30}; do
  NEW_MASTER=$(redis-cli -h "${SENTINEL_HOST}" -p "${SENTINEL_PORT}" SENTINEL get-master-addr-by-name "${MASTER_NAME}" | head -n1)
  NEW_PORT=$(redis-cli -h "${SENTINEL_HOST}" -p "${SENTINEL_PORT}" SENTINEL get-master-addr-by-name "${MASTER_NAME}" | tail -n1)

  if [ "${NEW_MASTER}:${NEW_PORT}" != "${CURRENT_MASTER}:${CURRENT_PORT}" ]; then
    echo ""
    echo "✓ Failover completed!"
    echo ""
    echo "Old Master: ${CURRENT_MASTER}:${CURRENT_PORT}"
    echo "New Master: ${NEW_MASTER}:${NEW_PORT}"
    break
  fi

  echo -n "."
  sleep 1
done

# Verify new master is reachable
echo ""
echo "Step 4: Verifying new master…"
if redis-cli -h "${NEW_MASTER}" -p "${NEW_PORT}" ping >/dev/null 2>&1; then
  echo "✓ New master is reachable and responding"
else
  echo "❌ New master is not reachable"
  exit 1
fi

# Show final status
echo ""
echo "Step 5: Final configuration:"
echo "----------------------------"
redis-cli -h "${SENTINEL_HOST}" -p "${SENTINEL_PORT}" SENTINEL master "${MASTER_NAME}"

echo ""
echo "========================================="
echo "✅ Failover test completed successfully"
echo "========================================="
echo ""
echo "Note: Old master will reconnect as slave automatically"
