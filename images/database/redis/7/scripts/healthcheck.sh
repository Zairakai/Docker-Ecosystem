#!/bin/bash
set -eo pipefail

# Redis 7 Health Check Script
# Comprehensive health monitoring for Redis container

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Health check configuration
TIMEOUT=10
MEMORY_USAGE_THRESHOLD=85   # Percentage
CLIENT_CONNECTIONS_THRESHOLD=80  # Percentage
# shellcheck disable=SC2034
LATENCY_THRESHOLD=100     # Milliseconds
FRAGMENTATION_THRESHOLD=1.5   # Memory fragmentation ratio

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

# Function to check basic Redis connectivity
check_redis_ping() {
  log "Checking Redis connectivity…"

  if timeout $TIMEOUT redis-cli ping >/dev/null 2>&1; then
    local result
    result=$(timeout $TIMEOUT redis-cli ping 2>/dev/null)
    if [ "$result" = "PONG" ]; then
      log_success "Redis is responding to ping"
      return 0
    else
      log_error "Redis ping returned unexpected result: $result"
      return 1
    fi
  else
    log_error "Redis is not responding to ping"
    return 1
  fi
}

# Function to check Redis server info
check_redis_info() {
  log "Checking Redis server information…"

  local server_info
  if server_info=$(timeout $TIMEOUT redis-cli info server 2>/dev/null); then
    local redis_version
    redis_version=$(echo "$server_info" | grep "redis_version:" | cut -d: -f2 | tr -d '\r')
    local uptime
    uptime=$(echo "$server_info" | grep "uptime_in_seconds:" | cut -d: -f2 | tr -d '\r')
    local role
    role=$(echo "$server_info" | grep "role:" | cut -d: -f2 | tr -d '\r')

    log "Redis version: $redis_version"
    log "Uptime: ${uptime}s"
    log "Role: $role"

    log_success "Redis server info check passed"
    return 0
  else
    log_error "Failed to retrieve Redis server information"
    return 1
  fi
}

# Function to check memory usage
check_memory_usage() {
  log "Checking Redis memory usage…"

  local memory_info
  if memory_info=$(timeout $TIMEOUT redis-cli info memory 2>/dev/null); then
    local used_memory
    used_memory=$(echo "$memory_info" | grep "used_memory:" | cut -d: -f2 | tr -d '\r')
    local maxmemory
    maxmemory=$(echo "$memory_info" | grep "maxmemory:" | cut -d: -f2 | tr -d '\r')
    local used_memory_human
    used_memory_human=$(echo "$memory_info" | grep "used_memory_human:" | cut -d: -f2 | tr -d '\r')
    local maxmemory_human
    maxmemory_human=$(echo "$memory_info" | grep "maxmemory_human:" | cut -d: -f2 | tr -d '\r')
    local fragmentation_ratio
    fragmentation_ratio=$(echo "$memory_info" | grep "mem_fragmentation_ratio:" | cut -d: -f2 | tr -d '\r')

    log "Used memory: $used_memory_human"
    log "Max memory: $maxmemory_human"
    log "Memory fragmentation ratio: $fragmentation_ratio"

    # Check memory usage percentage
    if [ "$maxmemory" -gt 0 ]; then
      local usage_percent
      usage_percent=$((used_memory * 100 / maxmemory))

      if [ $usage_percent -gt $MEMORY_USAGE_THRESHOLD ]; then
        log_warning "High memory usage: $usage_percent% (threshold: $MEMORY_USAGE_THRESHOLD%)"
        return 1
      else
        log_success "Memory usage is healthy: $usage_percent%"
      fi
    else
      log_warning "No memory limit configured"
    fi

    # Check memory fragmentation
    if [ -n "$fragmentation_ratio" ]; then
      local frag_check
      frag_check=$(echo "$fragmentation_ratio > $FRAGMENTATION_THRESHOLD" | bc -l 2>/dev/null || echo "0")
      if [ "$frag_check" = "1" ]; then
        log_warning "High memory fragmentation: $fragmentation_ratio (threshold: $FRAGMENTATION_THRESHOLD)"
        return 1
      else
        log_success "Memory fragmentation is acceptable: $fragmentation_ratio"
      fi
    fi

    return 0
  else
    log_error "Failed to retrieve Redis memory information"
    return 1
  fi
}

# Function to check client connections
check_client_connections() {
  log "Checking Redis client connections…"

  local clients_info
  if clients_info=$(timeout $TIMEOUT redis-cli info clients 2>/dev/null); then
    local connected_clients
    connected_clients=$(echo "$clients_info" | grep "connected_clients:" | cut -d: -f2 | tr -d '\r')
    local blocked_clients
    blocked_clients=$(echo "$clients_info" | grep "blocked_clients:" | cut -d: -f2 | tr -d '\r')
    local maxclients
    maxclients=$(timeout $TIMEOUT redis-cli config get maxclients 2>/dev/null | tail -1)

    log "Connected clients: $connected_clients"
    log "Blocked clients: $blocked_clients"
    log "Max clients: $maxclients"

    # Check client connection percentage
    if [ -n "$maxclients" ] && [ "$maxclients" -gt 0 ]; then
      local usage_percent
      usage_percent=$((connected_clients * 100 / maxclients))

      if [ $usage_percent -gt $CLIENT_CONNECTIONS_THRESHOLD ]; then
        log_warning "High client connection usage: $usage_percent% (threshold: $CLIENT_CONNECTIONS_THRESHOLD%)"
        return 1
      else
        log_success "Client connection usage is healthy: $usage_percent%"
      fi
    else
      log_warning "Could not retrieve maxclients setting"
    fi

    # Check for blocked clients
    if [ "$blocked_clients" -gt 0 ]; then
      log_warning "Found $blocked_clients blocked clients"
      return 1
    else
      log_success "No blocked clients"
    fi

    return 0
  else
    log_error "Failed to retrieve Redis client information"
    return 1
  fi
}

# Function to check keyspace statistics
check_keyspace() {
  log "Checking Redis keyspace…"

  local keyspace_info
  if keyspace_info=$(timeout $TIMEOUT redis-cli info keyspace 2>/dev/null); then
    if [ -n "$keyspace_info" ] && [ "$keyspace_info" != "" ]; then
      # Parse keyspace information
      local db_count
      db_count=$(echo "$keyspace_info" | grep -c "^db[0-9]" || echo "0")
      log "Active databases: $db_count"

      # Show statistics for each database
      echo "$keyspace_info" | grep "^db[0-9]" | while IFS= read -r line; do
        local db_name
        db_name=$(echo "$line" | cut -d: -f1)
        local db_stats
        db_stats=$(echo "$line" | cut -d: -f2)
        log "Database $db_name: $db_stats"
      done

      log_success "Keyspace information retrieved"
    else
      log "No keys found in keyspace"
    fi

    return 0
  else
    log_error "Failed to retrieve Redis keyspace information"
    return 1
  fi
}

# Function to check replication status
check_replication() {
  log "Checking Redis replication status…"

  local replication_info
  if replication_info=$(timeout $TIMEOUT redis-cli info replication 2>/dev/null); then
    local role
    role=$(echo "$replication_info" | grep "role:" | cut -d: -f2 | tr -d '\r')
    local connected_slaves
    connected_slaves=$(echo "$replication_info" | grep "connected_slaves:" | cut -d: -f2 | tr -d '\r')

    log "Redis role: $role"

    if [ "$role" = "master" ]; then
      log "Connected slaves: $connected_slaves"

      if [ "$connected_slaves" -gt 0 ]; then
        # Check slave lag
        local slave_lag
        slave_lag=$(echo "$replication_info" | grep "slave.*lag=" | head -1 | sed 's/.*lag=\([0-9]*\).*/\1/')
        if [ -n "$slave_lag" ]; then
          log "Slave lag: ${slave_lag}s"
          if [ "$slave_lag" -gt 5 ]; then
            log_warning "High slave lag detected: ${slave_lag}s"
            return 1
          fi
        fi
      fi

      log_success "Replication status is healthy"
    elif [ "$role" = "slave" ]; then
      local master_link_status
      master_link_status=$(echo "$replication_info" | grep "master_link_status:" | cut -d: -f2 | tr -d '\r')
      local master_last_io_seconds
      master_last_io_seconds=$(echo "$replication_info" | grep "master_last_io_seconds_ago:" | cut -d: -f2 | tr -d '\r')

      log "Master link status: $master_link_status"
      log "Last master I/O: ${master_last_io_seconds}s ago"

      if [ "$master_link_status" != "up" ]; then
        log_error "Master link is down"
        return 1
      fi

      if [ "$master_last_io_seconds" -gt 30 ]; then
        log_warning "Master I/O delay: ${master_last_io_seconds}s"
        return 1
      fi

      log_success "Slave replication is healthy"
    else
      log_success "Redis is running in standalone mode"
    fi

    return 0
  else
    log_error "Failed to retrieve Redis replication information"
    return 1
  fi
}

# Function to check persistence status
check_persistence() {
  log "Checking Redis persistence status…"

  local persistence_info
  if persistence_info=$(timeout $TIMEOUT redis-cli info persistence 2>/dev/null); then
    local rdb_last_save
    rdb_last_save=$(echo "$persistence_info" | grep "rdb_last_save_time:" | cut -d: -f2 | tr -d '\r')
    local rdb_last_bgsave_status
    rdb_last_bgsave_status=$(echo "$persistence_info" | grep "rdb_last_bgsave_status:" | cut -d: -f2 | tr -d '\r')
    local aof_enabled
    aof_enabled=$(echo "$persistence_info" | grep "aof_enabled:" | cut -d: -f2 | tr -d '\r')

    if [ -n "$rdb_last_save" ]; then
      local current_time
      current_time=$(date +%s)
      local time_since_save
      time_since_save=$((current_time - rdb_last_save))
      log "Last RDB save: ${time_since_save}s ago"
      log "Last RDB save status: $rdb_last_bgsave_status"

      if [ "$rdb_last_bgsave_status" != "ok" ]; then
        log_warning "Last RDB save failed: $rdb_last_bgsave_status"
        return 1
      fi
    fi

    if [ "$aof_enabled" = "1" ]; then
      local aof_last_rewrite_status
      aof_last_rewrite_status=$(echo "$persistence_info" | grep "aof_last_rewrite_status:" | cut -d: -f2 | tr -d '\r')
      local aof_last_write_status
      aof_last_write_status=$(echo "$persistence_info" | grep "aof_last_write_status:" | cut -d: -f2 | tr -d '\r')

      log "AOF enabled: yes"
      log "AOF last rewrite status: $aof_last_rewrite_status"
      log "AOF last write status: $aof_last_write_status"

      if [ "$aof_last_write_status" != "ok" ]; then
        log_warning "AOF write failed: $aof_last_write_status"
        return 1
      fi
    else
      log "AOF enabled: no"
    fi

    log_success "Persistence status is healthy"
    return 0
  else
    log_error "Failed to retrieve Redis persistence information"
    return 1
  fi
}

# Function to test Redis operations
test_redis_operations() {
  log "Testing Redis operations…"

  local test_key
  test_key="healthcheck:$(date +%s)"
  local test_value
  test_value="test_value_$(date +%s)"

  # Test SET operation
  if timeout $TIMEOUT redis-cli set "$test_key" "$test_value" >/dev/null 2>&1; then
    log_success "SET operation successful"
  else
    log_error "SET operation failed"
    return 1
  fi

  # Test GET operation
  local retrieved_value
  if retrieved_value=$(timeout $TIMEOUT redis-cli get "$test_key" 2>/dev/null); then
    if [ "$retrieved_value" = "$test_value" ]; then
      log_success "GET operation successful"
    else
      log_error "GET operation returned incorrect value"
      return 1
    fi
  else
    log_error "GET operation failed"
    return 1
  fi

  # Test DEL operation
  if timeout $TIMEOUT redis-cli del "$test_key" >/dev/null 2>&1; then
    log_success "DEL operation successful"
  else
    log_error "DEL operation failed"
    return 1
  fi

  return 0
}

# Function to check slow log
check_slow_log() {
  log "Checking Redis slow log…"

  local slow_log_len
  if slow_log_len=$(timeout $TIMEOUT redis-cli slowlog len 2>/dev/null); then
    log "Slow log entries: $slow_log_len"

    if [ "$slow_log_len" -gt 10 ]; then
      log_warning "High number of slow queries: $slow_log_len"

      # Show recent slow queries
      timeout $TIMEOUT redis-cli slowlog get 3 2>/dev/null | head -20
      return 1
    else
      log_success "Slow log count is acceptable"
    fi

    return 0
  else
    log_error "Failed to retrieve slow log information"
    return 1
  fi
}

# Function to perform comprehensive health check
perform_health_check() {
  local exit_code=0
  local checks_passed=0
  local total_checks=0

  log "Starting comprehensive Redis health check…"

  # Basic connectivity checks
  if check_redis_ping; then
    ((checks_passed++))
  else
    exit_code=1
  fi
  ((total_checks++))

  if check_redis_info; then
    ((checks_passed++))
  else
    exit_code=1
  fi
  ((total_checks++))

  # Resource and performance checks
  if check_memory_usage; then
    ((checks_passed++))
  else
    exit_code=1
  fi
  ((total_checks++))

  if check_client_connections; then
    ((checks_passed++))
  else
    exit_code=1
  fi
  ((total_checks++))

  if check_keyspace; then
    ((checks_passed++))
  else
    exit_code=1
  fi
  ((total_checks++))

  if check_replication; then
    ((checks_passed++))
  else
    exit_code=1
  fi
  ((total_checks++))

  if check_persistence; then
    ((checks_passed++))
  else
    exit_code=1
  fi
  ((total_checks++))

  if test_redis_operations; then
    ((checks_passed++))
  else
    exit_code=1
  fi
  ((total_checks++))

  if check_slow_log; then
    ((checks_passed++))
  else
    exit_code=1
  fi
  ((total_checks++))

  # Summary
  log "Health check completed: $checks_passed/$total_checks checks passed"

  if [ $exit_code -eq 0 ]; then
    log_success "All health checks passed"
  else
    log_error "Some health checks failed"
  fi

  return $exit_code
}

# Main execution
main() {
  # Set Redis authentication if password is available
  if [ -f "/run/secrets/redis_password" ]; then
    export REDISCLI_AUTH
    REDISCLI_AUTH="$(cat /run/secrets/redis_password)"
  elif [ -n "$REDIS_PASSWORD" ]; then
    export REDISCLI_AUTH="$REDIS_PASSWORD"
  fi

  # Check if we're in a testing/CI environment (simplified healthcheck)
  if [ "${CI:-false}" = "true" ] || [ "${TESTING_MODE:-false}" = "true" ]; then
    log "Running simplified health check for CI/Testing environment…"

    # Just check basic connectivity for CI (ping only)
    if timeout 5 redis-cli ping >/dev/null 2>&1; then
      local result
      result=$(timeout 5 redis-cli ping 2>/dev/null)
      if [ "$result" = "PONG" ]; then
        log_success "Redis is responding (CI mode)"
        exit 0
      else
        log_error "Redis ping returned unexpected result: $result (CI mode)"
        exit 1
      fi
    else
      log_error "Redis is not responding (CI mode)"
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
