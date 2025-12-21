#!/bin/bash
# ================================
# MySQL Slave Replication Setup
# ================================
# Configures MySQL slave to replicate from master

set -e

echo "========================================="
echo "MySQL Slave Replication Setup"
echo "========================================="

# Required environment variables
: "${MYSQL_MASTER_HOST:?MYSQL_MASTER_HOST is required}"
: "${MYSQL_MASTER_PORT:=3306}"
: "${REPLICATION_USER:=replication}"
: "${REPLICATION_PASSWORD:?REPLICATION_PASSWORD is required}"

echo "Master Host: ${MYSQL_MASTER_HOST}"
echo "Master Port: ${MYSQL_MASTER_PORT}"
echo "Replication User: ${REPLICATION_USER}"

# Wait for MySQL to be ready
until mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "SELECT 1" >/dev/null 2>&1; do
  echo "Waiting for MySQL to be ready…"
  sleep 2
done

echo "✓ MySQL is ready"

# Wait for master to be ready
until mysql -h "${MYSQL_MASTER_HOST}" -P "${MYSQL_MASTER_PORT}" -u "${REPLICATION_USER}" -p"${REPLICATION_PASSWORD}" -e "SELECT 1" >/dev/null 2>&1; do
  echo "Waiting for master to be ready…"
  sleep 2
done

echo "✓ Master is reachable"

# Get master status using GTID (no need for log file/position)
mysql -u root -p"${MYSQL_ROOT_PASSWORD}" <<-EOSQL
  -- Stop slave if running
  STOP SLAVE;

  -- Reset slave
  RESET SLAVE ALL;

  -- Configure master connection
  CHANGE MASTER TO
    MASTER_HOST='${MYSQL_MASTER_HOST}',
    MASTER_PORT=${MYSQL_MASTER_PORT},
    MASTER_USER='${REPLICATION_USER}',
    MASTER_PASSWORD='${REPLICATION_PASSWORD}',
    MASTER_AUTO_POSITION=1;  -- Use GTID auto-positioning

  -- Start slave
  START SLAVE;

  -- Show slave status
  SHOW SLAVE STATUS\G
EOSQL

echo "✓ Slave configuration complete"

# Check slave status
sleep 2
mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "SHOW SLAVE STATUS\G" > /tmp/slave-status.txt

# Verify replication is running
if grep -q "Slave_IO_Running: Yes" /tmp/slave-status.txt && grep -q "Slave_SQL_Running: Yes" /tmp/slave-status.txt; then
  echo "========================================="
  echo "✅ REPLICATION IS RUNNING"
  echo "========================================="
  cat /tmp/slave-status.txt | grep -E "Slave_IO_Running:|Slave_SQL_Running:|Seconds_Behind_Master:|Master_Host:"
else
  echo "========================================="
  echo "⚠️  REPLICATION STATUS CHECK FAILED"
  echo "========================================="
  cat /tmp/slave-status.txt | grep -E "Slave_IO_Running:|Slave_SQL_Running:|Last_IO_Error:|Last_SQL_Error:"
  exit 1
fi

echo ""
echo "Slave is successfully replicating from master!"
echo ""
