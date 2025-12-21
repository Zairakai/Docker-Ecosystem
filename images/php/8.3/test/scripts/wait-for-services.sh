#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
TIMEOUT="${WAIT_TIMEOUT:-300}"  # 5 minutes default
INTERVAL="${WAIT_INTERVAL:-2}"  # Check every 2 seconds

# Service definitions
MYSQL_HOST="${MYSQL_HOST:-mysql}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
POSTGRES_HOST="${POSTGRES_HOST:-postgres}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
REDIS_HOST="${REDIS_HOST:-redis}"
REDIS_PORT="${REDIS_PORT:-6379}"
ELASTICSEARCH_HOST="${ELASTICSEARCH_HOST:-elasticsearch}"
ELASTICSEARCH_PORT="${ELASTICSEARCH_PORT:-9200}"
MEMCACHED_HOST="${MEMCACHED_HOST:-memcached}"
MEMCACHED_PORT="${MEMCACHED_PORT:-11211}"

# Services to wait for (can be overridden by environment)
WAIT_FOR_SERVICES="${WAIT_FOR_SERVICES:-}"

# Logging functions
log() {
  echo -e "${BLUE}[WAIT-FOR-SERVICES]${NC} $1"
}

error() {
  echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warn() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if a TCP port is open
check_tcp_port() {
  local host="$1"
  local port="$2"
  local timeout="${3:-5}"

  if timeout "$timeout" bash -c "exec 3<>/dev/tcp/$host/$port" 2>/dev/null; then
    exec 3<&-
    exec 3>&-
    return 0
  else
    return 1
  fi
}

# Check if a service is responding via HTTP
check_http_service() {
  local url="$1"
  local timeout="${2:-5}"

  if curl -s --max-time "$timeout" "$url" >/dev/null 2>&1; then
    return 0
  else
    return 1
  fi
}

# Wait for MySQL/MariaDB
wait_for_mysql() {
  local host="$1"
  local port="$2"

  log "Waiting for MySQL/MariaDB at $host:$port…"

  local start_time
  start_time=$(date +%s)
  while [ $(($(date +%s) - start_time)) -lt $TIMEOUT ]; do
    if check_tcp_port "$host" "$port"; then
      # Additional check with mysql client if available
      if command -v mysql >/dev/null 2>&1; then
        if mysql -h"$host" -P"$port" -u"${MYSQL_USER:-root}" -p"${MYSQL_PASSWORD:-}" -e "SELECT 1" >/dev/null 2>&1; then
          success "MySQL/MariaDB is ready at $host:$port"
          return 0
        fi
      else
        success "MySQL/MariaDB port is open at $host:$port"
        return 0
      fi
    fi

    sleep $INTERVAL
  done

  error "MySQL/MariaDB at $host:$port not ready within $TIMEOUT seconds"
  return 1
}

# Wait for PostgreSQL
wait_for_postgres() {
  local host="$1"
  local port="$2"

  log "Waiting for PostgreSQL at $host:$port…"

  local start_time
  start_time=$(date +%s)
  while [ $(($(date +%s) - start_time)) -lt $TIMEOUT ]; do
    if check_tcp_port "$host" "$port"; then
      # Additional check with psql client if available
      if command -v psql >/dev/null 2>&1; then
        if PGPASSWORD="${POSTGRES_PASSWORD:-}" psql -h"$host" -p"$port" -U"${POSTGRES_USER:-postgres}" -d"${POSTGRES_DB:-postgres}" -c "SELECT 1" >/dev/null 2>&1; then
          success "PostgreSQL is ready at $host:$port"
          return 0
        fi
      else
        success "PostgreSQL port is open at $host:$port"
        return 0
      fi
    fi

    sleep $INTERVAL
  done

  error "PostgreSQL at $host:$port not ready within $TIMEOUT seconds"
  return 1
}

# Wait for Redis
wait_for_redis() {
  local host="$1"
  local port="$2"

  log "Waiting for Redis at $host:$port…"

  local start_time
  start_time=$(date +%s)
  while [ $(($(date +%s) - start_time)) -lt $TIMEOUT ]; do
    if check_tcp_port "$host" "$port"; then
      # Additional check with redis-cli if available
      if command -v redis-cli >/dev/null 2>&1; then
        if redis-cli -h "$host" -p "$port" ping | grep -q "PONG"; then
          success "Redis is ready at $host:$port"
          return 0
        fi
      else
        success "Redis port is open at $host:$port"
        return 0
      fi
    fi

    sleep $INTERVAL
  done

  error "Redis at $host:$port not ready within $TIMEOUT seconds"
  return 1
}

# Wait for Elasticsearch
wait_for_elasticsearch() {
  local host="$1"
  local port="$2"

  log "Waiting for Elasticsearch at $host:$port…"

  local url="http://$host:$port/_cluster/health"
  local start_time
  start_time=$(date +%s)

  while [ $(($(date +%s) - start_time)) -lt $TIMEOUT ]; do
    if check_http_service "$url"; then
      # Check if cluster is at least yellow
      local status
      status=$(curl -s "$url" 2>/dev/null | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
      if [ "$status" = "green" ] || [ "$status" = "yellow" ]; then
        success "Elasticsearch is ready at $host:$port (status: $status)"
        return 0
      else
        log "Elasticsearch responding but status is: $status"
      fi
    fi

    sleep $INTERVAL
  done

  error "Elasticsearch at $host:$port not ready within $TIMEOUT seconds"
  return 1
}

# Wait for Memcached
wait_for_memcached() {
  local host="$1"
  local port="$2"

  log "Waiting for Memcached at $host:$port…"

  local start_time
  start_time=$(date +%s)
  while [ $(($(date +%s) - start_time)) -lt $TIMEOUT ]; do
    if check_tcp_port "$host" "$port"; then
      # Additional check with telnet-like command
      if echo "version" | nc -w 1 "$host" "$port" 2>/dev/null | grep -q "VERSION"; then
        success "Memcached is ready at $host:$port"
        return 0
      else
        success "Memcached port is open at $host:$port"
        return 0
      fi
    fi

    sleep $INTERVAL
  done

  error "Memcached at $host:$port not ready within $TIMEOUT seconds"
  return 1
}

# Wait for a generic HTTP service
wait_for_http() {
  local url="$1"
  local name="${2:-HTTP service}"

  log "Waiting for $name at $url…"

  local start_time
  start_time=$(date +%s)
  while [ $(($(date +%s) - start_time)) -lt $TIMEOUT ]; do
    if check_http_service "$url"; then
      success "$name is ready at $url"
      return 0
    fi

    sleep $INTERVAL
  done

  error "$name at $url not ready within $TIMEOUT seconds"
  return 1
}

# Auto-detect services to wait for
auto_detect_services() {
  local services=()

  # Check environment variables for database connections
  if [ -n "$DB_HOST" ] || [ -n "$DATABASE_URL" ]; then
    local db_host="${DB_HOST:-$MYSQL_HOST}"
    local db_port="${DB_PORT:-$MYSQL_PORT}"

    if [ "$DB_CONNECTION" = "pgsql" ] || [[ "$DATABASE_URL" =~ ^postgres:// ]]; then
      services+=("postgres:${POSTGRES_HOST}:${POSTGRES_PORT}")
    else
      services+=("mysql:${db_host}:${db_port}")
    fi
  fi

  # Check for Redis
  if [ -n "$REDIS_HOST" ] || [ -n "$REDIS_URL" ]; then
    services+=("redis:${REDIS_HOST}:${REDIS_PORT}")
  fi

  # Check for Elasticsearch
  if [ -n "$ELASTICSEARCH_HOST" ] || [ -n "$ELASTICSEARCH_URL" ]; then
    services+=("elasticsearch:${ELASTICSEARCH_HOST}:${ELASTICSEARCH_PORT}")
  fi

  # Check for Memcached
  if [ -n "$MEMCACHED_HOST" ]; then
    services+=("memcached:${MEMCACHED_HOST}:${MEMCACHED_PORT}")
  fi

  # Output detected services
  if [ ${#services[@]} -gt 0 ]; then
    log "Auto-detected services: ${services[*]}"
    echo "${services[*]}"
  else
    log "No services auto-detected"
    echo ""
  fi
}

# Parse and wait for services
wait_for_all_services() {
  local services_list="$1"

  if [ -z "$services_list" ]; then
    log "No services specified, auto-detecting…"
    services_list=$(auto_detect_services)
  fi

  if [ -z "$services_list" ]; then
    log "No services to wait for"
    return 0
  fi

  log "Waiting for services: $services_list"

  local overall_success=true

  # Parse services list (format: service:host:port or service:url)
  for service_spec in $services_list; do
    IFS=':' read -r service_type service_host service_port <<< "$service_spec"

    case "$service_type" in
      "mysql"|"mariadb")
        if ! wait_for_mysql "$service_host" "$service_port"; then
          overall_success=false
        fi
        ;;
      "postgres"|"postgresql")
        if ! wait_for_postgres "$service_host" "$service_port"; then
          overall_success=false
        fi
        ;;
      "redis")
        if ! wait_for_redis "$service_host" "$service_port"; then
          overall_success=false
        fi
        ;;
      "elasticsearch"|"elastic")
        if ! wait_for_elasticsearch "$service_host" "$service_port"; then
          overall_success=false
        fi
        ;;
      "memcached")
        if ! wait_for_memcached "$service_host" "$service_port"; then
          overall_success=false
        fi
        ;;
      "http"|"https")
        local url="${service_type}://${service_host}:${service_port}"
        if ! wait_for_http "$url" "HTTP service"; then
          overall_success=false
        fi
        ;;
      *)
        warn "Unknown service type: $service_type, treating as TCP port check"
        if ! check_tcp_port "$service_host" "$service_port"; then
          error "Service $service_type at $service_host:$service_port not ready"
          overall_success=false
        else
          success "Service $service_type at $service_host:$service_port is ready"
        fi
        ;;
    esac
  done

  if [ "$overall_success" = true ]; then
    success "All services are ready"
    return 0
  else
    error "Some services are not ready"
    return 1
  fi
}

# Main function
main() {
  log "Starting service readiness check…"
  log "Timeout: ${TIMEOUT}s, Check interval: ${INTERVAL}s"

  if ! wait_for_all_services "$WAIT_FOR_SERVICES"; then
    error "Service readiness check failed"
    exit 1
  fi

  success "Service readiness check completed successfully"
}

# Handle script arguments
case "$1" in
  --help|-h)
    echo "Usage: $0 [options]"
    echo ""
    echo "Environment variables:"
    echo "  WAIT_FOR_SERVICES    Space-separated list of services (format: type:host:port)"
    echo "  WAIT_TIMEOUT         Maximum wait time in seconds (default: 300)"
    echo "  WAIT_INTERVAL        Check interval in seconds (default: 2)"
    echo ""
    echo "Supported service types:"
    echo "  mysql:host:port      MySQL/MariaDB"
    echo "  postgres:host:port   PostgreSQL"
    echo "  redis:host:port      Redis"
    echo "  elasticsearch:host:port  Elasticsearch"
    echo "  memcached:host:port  Memcached"
    echo "  http:host:port       HTTP service"
    echo ""
    echo "Examples:"
    echo "  WAIT_FOR_SERVICES=\"mysql:db:3306 redis:cache:6379\" $0"
    echo "  WAIT_FOR_SERVICES=\"postgres:db:5432\" $0"
    exit 0
    ;;
  *)
    main "$@"
    ;;
esac
