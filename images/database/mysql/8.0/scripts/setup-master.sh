#!/bin/bash
# ================================
# MySQL Master Replication Setup
# ================================
# Sets up MySQL master for replication with slaves

set -e

echo "========================================="
echo "MySQL Master Replication Setup"
echo "========================================="

# Wait for MySQL to be ready
until mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "SELECT 1" >/dev/null 2>&1; do
  echo "Waiting for MySQL to be ready…"
  sleep 2
done

echo "✓ MySQL is ready"

# Create replication user
mysql -u root -p"${MYSQL_ROOT_PASSWORD}" <<-EOSQL
  -- Create replication user
  CREATE USER IF NOT EXISTS 'replication'@'%' IDENTIFIED BY '${REPLICATION_PASSWORD}';
  GRANT REPLICATION SLAVE ON *.* TO 'replication'@'%';

  -- Create monitoring user (for health checks)
  CREATE USER IF NOT EXISTS 'monitor'@'%' IDENTIFIED BY '${MONITOR_PASSWORD}';
  GRANT REPLICATION CLIENT, PROCESS ON *.* TO 'monitor'@'%';

  -- Flush privileges
  FLUSH PRIVILEGES;

  -- Show master status
  SHOW MASTER STATUS\G
EOSQL

echo "✓ Replication user created"
echo "✓ Master setup complete"

# Export master status for slaves
mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "SHOW MASTER STATUS\G" > /tmp/master-status.txt
cat /tmp/master-status.txt

echo "========================================="
echo "Master Binary Log File and Position:"
cat /tmp/master-status.txt | grep -E "File:|Position:"
echo "========================================="
echo ""
echo "To configure slave, use these values from above output"
echo ""
