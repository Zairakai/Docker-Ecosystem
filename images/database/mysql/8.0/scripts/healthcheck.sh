#!/bin/bash
set -eo pipefail

# MySQL 8.4 Health Check Script
# Comprehensive health monitoring for MySQL container

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Health check configuration
TIMEOUT=10
MAX_CONNECTIONS_THRESHOLD=80  # Percentage
SLOW_QUERY_THRESHOLD=10     # Count per check
DISK_USAGE_THRESHOLD=85     # Percentage

# Logging function
log() {
  echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] [HEALTHCHECK]${NC} $1"
}

log_error() {
  echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] [HEALTHCHECK] ERROR:${NC} $1" >&2
}

log_warning() {
  echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] [HEALTHCHECK] WARNING:${NC} $1"
}

log_success() {
  echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] [HEALTHCHECK] SUCCESS:${NC} $1"
}

# Function to check basic MySQL connectivity
check_mysql_ping() {
  log "Checking MySQL connectivity…"

  # Use socket for local healthcheck (no password required)
  if timeout $TIMEOUT mysqladmin ping --socket=/var/run/mysqld/mysqld.sock --silent 2>/dev/null; then
    log_success "MySQL is responding to ping"
    return 0
  else
    log_error "MySQL is not responding to ping"
    return 1
  fi
}

# Function to check MySQL process status
check_mysql_status() {
  log "Checking MySQL process status…"

  # Use socket for local healthcheck (no password required)
  if timeout $TIMEOUT mysqladmin status --socket=/var/run/mysqld/mysqld.sock --silent 2>/dev/null > /dev/null; then
    log_success "MySQL status check passed"
    return 0
  else
    log_error "MySQL status check failed"
    return 1
  fi
}

# Function to check database connectivity
check_database_connectivity() {
  log "Checking database connectivity…"

  local query="SELECT 1 as healthcheck;"
  local result

  if result=$(timeout $TIMEOUT mysql --silent --skip-column-names -e "$query" 2>/dev/null); then
    if [ "$result" = "1" ]; then
      log_success "Database connectivity check passed"
      return 0
    else
      log_error "Database query returned unexpected result: $result"
      return 1
    fi
  else
    log_error "Database connectivity check failed"
    return 1
  fi
}

# Function to check connection count
check_connection_count() {
  log "Checking connection count…"

  local query="SHOW STATUS WHERE Variable_name IN ('Threads_connected', 'Max_used_connections');"
  local result
  local current_connections

  if result=$(timeout $TIMEOUT mysql --silent --skip-column-names -e "$query" 2>/dev/null); then
    current_connections=$(echo "$result" | grep "Threads_connected" | awk '{print $2}')

    # Get max_connections setting
    max_connections=$(timeout $TIMEOUT mysql --silent --skip-column-names -e "SHOW VARIABLES LIKE 'max_connections';" 2>/dev/null | awk '{print $2}')

    if [ -n "$current_connections" ] && [ -n "$max_connections" ]; then
      local usage_percent
      usage_percent=$((current_connections * 100 / max_connections))

      log "Current connections: $current_connections/$max_connections ($usage_percent%)"

      if [ $usage_percent -gt $MAX_CONNECTIONS_THRESHOLD ]; then
        log_warning "High connection usage: $usage_percent% (threshold: $MAX_CONNECTIONS_THRESHOLD%)"
        return 1
      else
        log_success "Connection count is healthy"
        return 0
      fi
    else
      log_error "Could not retrieve connection information"
      return 1
    fi
  else
    log_error "Connection count check failed"
    return 1
  fi
}

# Function to check InnoDB status
check_innodb_status() {
  log "Checking InnoDB status…"

  local query="SHOW ENGINE INNODB STATUS;"
  local result

  if result=$(timeout $TIMEOUT mysql --silent -e "$query" 2>/dev/null); then
    # Check for any obvious issues in InnoDB status
    if echo "$result" | grep -q "LATEST DEADLOCK INFORMATION"; then
      log_warning "Recent deadlocks detected in InnoDB"
    fi

    if echo "$result" | grep -q "BACKGROUND THREAD"; then
      log_success "InnoDB background threads are running"
      return 0
    else
      log_error "InnoDB status check failed"
      return 1
    fi
  else
    log_error "Could not retrieve InnoDB status"
    return 1
  fi
}

# Function to check slow query log
check_slow_queries() {
  log "Checking slow query statistics…"

  local query="SHOW GLOBAL STATUS LIKE 'Slow_queries';"
  local current_slow_queries
  local previous_slow_queries=0
  local slow_query_file="/tmp/mysql_slow_query_count"

  if current_slow_queries=$(timeout $TIMEOUT mysql --silent --skip-column-names -e "$query" 2>/dev/null | awk '{print $2}'); then
    # Read previous count if available
    if [ -f "$slow_query_file" ]; then
      previous_slow_queries=$(cat "$slow_query_file")
    fi

    # Calculate difference
    local slow_query_diff
    slow_query_diff=$((current_slow_queries - previous_slow_queries))

    # Save current count for next check
    echo "$current_slow_queries" > "$slow_query_file"

    log "Slow queries since last check: $slow_query_diff (total: $current_slow_queries)"

    if [ $slow_query_diff -gt $SLOW_QUERY_THRESHOLD ]; then
      log_warning "High number of slow queries detected: $slow_query_diff (threshold: $SLOW_QUERY_THRESHOLD)"
      return 1
    else
      log_success "Slow query count is acceptable"
      return 0
    fi
  else
    log_error "Could not retrieve slow query statistics"
    return 1
  fi
}

# Function to check disk usage
check_disk_usage() {
  log "Checking disk usage…"

  local data_dir="/var/lib/mysql"
  local usage_percent

  if usage_percent=$(df "$data_dir" | awk 'NR==2 {print $5}' | sed 's/%//'); then
    log "Disk usage for $data_dir: $usage_percent%"

    if [ "$usage_percent" -gt $DISK_USAGE_THRESHOLD ]; then
      log_warning "High disk usage: $usage_percent% (threshold: $DISK_USAGE_THRESHOLD%)"
      return 1
    else
      log_success "Disk usage is healthy"
      return 0
    fi
  else
    log_error "Could not check disk usage"
    return 1
  fi
}

# Function to check log files
check_log_files() {
  log "Checking log files…"

  local error_log="/var/log/mysql/error.log"
  local recent_errors

  if [ -f "$error_log" ]; then
    # Check for recent errors (last 5 minutes)
    recent_errors=$(find "$error_log" -mmin -5 -exec grep -i "error\|fatal\|crash" {} \; 2>/dev/null | wc -l)

    if [ "$recent_errors" -gt 0 ]; then
      log_warning "Found $recent_errors recent errors in error log"
      return 1
    else
      log_success "No recent errors in log files"
      return 0
    fi
  else
    log_warning "Error log file not found: $error_log"
    return 0  # Don't fail health check for missing log file
  fi
}

# Function to check replication status (if applicable)
check_replication_status() {
  local slave_status

  if slave_status=$(timeout $TIMEOUT mysql --silent -e "SHOW SLAVE STATUS\G" 2>/dev/null); then
    if [ -n "$slave_status" ]; then
      log "Checking replication status…"

      local slave_io_running
      slave_io_running=$(echo "$slave_status" | grep "Slave_IO_Running:" | awk '{print $2}')
      local slave_sql_running
      slave_sql_running=$(echo "$slave_status" | grep "Slave_SQL_Running:" | awk '{print $2}')

      if [ "$slave_io_running" = "Yes" ] && [ "$slave_sql_running" = "Yes" ]; then
        log_success "Replication is healthy"
        return 0
      else
        log_error "Replication issues detected - IO: $slave_io_running, SQL: $slave_sql_running"
        return 1
      fi
    fi
  fi

  # No replication configured, skip check
  return 0
}

# Function to perform comprehensive health check
perform_health_check() {
  local checks_passed=0
  local total_checks=0
  local critical_checks_passed=0
  local critical_checks_total=0

  log "Starting comprehensive MySQL health check…"

  # CRITICAL: Basic connectivity checks (must pass)
  if check_mysql_ping; then
    ((checks_passed++))
    ((critical_checks_passed++))
  fi
  ((total_checks++))
  ((critical_checks_total++))

  if check_mysql_status; then
    ((checks_passed++))
    ((critical_checks_passed++))
  fi
  ((total_checks++))
  ((critical_checks_total++))

  if check_database_connectivity; then
    ((checks_passed++))
    ((critical_checks_passed++))
  fi
  ((total_checks++))
  ((critical_checks_total++))

  # NON-CRITICAL: Performance and resource checks (warnings only, don't fail healthcheck)
  if check_connection_count; then
    ((checks_passed++))
  fi
  ((total_checks++))

  if check_innodb_status; then
    ((checks_passed++))
  fi
  ((total_checks++))

  if check_slow_queries; then
    ((checks_passed++))
  fi
  ((total_checks++))

  if check_disk_usage; then
    ((checks_passed++))
  fi
  ((total_checks++))

  if check_log_files; then
    ((checks_passed++))
  fi
  ((total_checks++))

  if check_replication_status; then
    ((checks_passed++))
  fi
  ((total_checks++))

  # Summary
  log "Health check completed: $checks_passed/$total_checks checks passed ($critical_checks_passed/$critical_checks_total critical)"

  # Only fail if critical checks failed
  if [ $critical_checks_passed -eq $critical_checks_total ]; then
    log_success "All critical health checks passed ($checks_passed/$total_checks total)"
    return 0
  else
    log_error "Critical health checks failed ($critical_checks_passed/$critical_checks_total passed)"
    return 1
  fi
}

# Main execution
main() {
  # Set default credentials if not provided
  export MYSQL_PWD="${MYSQL_ROOT_PASSWORD:-root}"

  # Check if we're in a testing/CI environment (simplified healthcheck)
  if [ "${CI:-false}" = "true" ] || [ "${TESTING_MODE:-false}" = "true" ]; then
    log "Running simplified health check for CI/Testing environment…"

    # Just check basic connectivity for CI using socket (no password needed)
    if timeout 5 mysqladmin ping --socket=/var/run/mysqld/mysqld.sock --silent 2>/dev/null; then
      log_success "MySQL is responding (CI mode)"
      exit 0
    else
      log_error "MySQL is not responding (CI mode)"
      exit 1
    fi
  fi

  # Perform comprehensive health check for production
  perform_health_check
  local result=$?

  # Exit with appropriate code
  exit $result
}

# Run main function
main "$@"
