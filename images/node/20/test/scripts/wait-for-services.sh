#!/bin/bash
set -euo pipefail

# Service dependency waiter script
# Waits for external services to be ready before running tests

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Configuration
readonly DEFAULT_TIMEOUT=300 # 5 minutes
readonly DEFAULT_INTERVAL=2

# Logging functions
log_info() {
  echo -e "${GREEN}[WAIT]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warn() {
  echo -e "${YELLOW}[WAIT]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

log_error() {
  echo -e "${RED}[WAIT]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

log_step() {
  echo -e "${BLUE}[WAIT]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Service check functions
check_http_service() {
  local url="$1"
  local expected_status="${2:-200}"

  if command -v curl >/dev/null 2>&1; then
    local response
    response=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
    [ "$response" = "$expected_status" ]
  elif command -v wget >/dev/null 2>&1; then
    wget --quiet --spider --timeout=10 "$url" 2>/dev/null
  else
    log_error "Neither curl nor wget available for HTTP checks"
    return 1
  fi
}

check_tcp_service() {
  local host="$1"
  local port="$2"

  if command -v nc >/dev/null 2>&1; then
    nc -z "$host" "$port" 2>/dev/null
  elif command -v telnet >/dev/null 2>&1; then
    timeout 5 bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null
  else
    log_error "Neither nc nor telnet available for TCP checks"
    return 1
  fi
}

check_database_service() {
  local type="$1"
  local host="$2"
  local port="$3"
  local database="${4:-}"
  local username="${5:-}"
  local password="${6:-}"

  case "$type" in
    "postgres"|"postgresql")
      if command -v psql >/dev/null 2>&1; then
        PGPASSWORD="$password" psql -h "$host" -p "$port" -U "$username" -d "$database" -c "SELECT 1;" >/dev/null 2>&1
      else
        check_tcp_service "$host" "$port"
      fi
      ;;
    "mysql"|"mariadb")
      if command -v mysql >/dev/null 2>&1; then
        mysql -h "$host" -P "$port" -u "$username" -p"$password" -e "SELECT 1;" "$database" >/dev/null 2>&1
      else
        check_tcp_service "$host" "$port"
      fi
      ;;
    "mongodb"|"mongo")
      if command -v mongo >/dev/null 2>&1; then
        mongo --host "$host:$port" --eval "db.adminCommand('ismaster')" >/dev/null 2>&1
      else
        check_tcp_service "$host" "$port"
      fi
      ;;
    "redis")
      if command -v redis-cli >/dev/null 2>&1; then
        redis-cli -h "$host" -p "$port" ping >/dev/null 2>&1
      else
        check_tcp_service "$host" "$port"
      fi
      ;;
    *)
      log_warn "Unknown database type: $type, falling back to TCP check"
      check_tcp_service "$host" "$port"
      ;;
  esac
}

check_elasticsearch_service() {
  local url="$1"

  if check_http_service "$url/_cluster/health"; then
    if command -v curl >/dev/null 2>&1; then
      local status
      status=$(curl -s "$url/_cluster/health" | grep -o '"status":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "unknown")
      [ "$status" = "green" ] || [ "$status" = "yellow" ]
    else
      true # If we can't check status, assume healthy if reachable
    fi
  else
    false
  fi
}

check_rabbitmq_service() {
  local url="$1"
  local username="${2:-guest}"
  local password="${3:-guest}"

  if command -v curl >/dev/null 2>&1; then
    curl -s -u "$username:$password" "$url/api/overview" >/dev/null 2>&1
  else
    # Fall back to TCP check on default port
    local host port
    host=$(echo "$url" | sed -n 's|.*://\\([^:/]*\\).*|\\1|p')
    port=$(echo "$url" | sed -n 's|.*:\\([0-9]*\\)/.*|\\1|p')
    [ -z "$port" ] && port=15672
    check_tcp_service "$host" "$port"
  fi
}

# Wait for a single service
wait_for_service() {
  local service_config="$1"
  local timeout="$2"
  local interval="$3"

  # Parse service configuration
  local service_type service_url service_host service_port
  local service_database service_username service_password

  if [[ "$service_config" =~ ^http ]]; then
    service_type="http"
    service_url="$service_config"
  elif [[ "$service_config" =~ ^([^:]+):([^:]+):([0-9]+)$ ]]; then
    service_type="${BASH_REMATCH[1]}"
    service_host="${BASH_REMATCH[2]}"
    service_port="${BASH_REMATCH[3]}"
  elif [[ "$service_config" =~ ^([^:]+):([^:]+):([0-9]+):([^:]*):([^:]*):(.*)$ ]]; then
    service_type="${BASH_REMATCH[1]}"
    service_host="${BASH_REMATCH[2]}"
    service_port="${BASH_REMATCH[3]}"
    service_database="${BASH_REMATCH[4]}"
    service_username="${BASH_REMATCH[5]}"
    service_password="${BASH_REMATCH[6]}"
  else
    log_error "Invalid service configuration: $service_config"
    return 1
  fi

  log_step "Waiting for $service_type service at $service_host:$service_port…"

  local start_time end_time elapsed
  start_time=$(date +%s)
  end_time=$((start_time + timeout))

  while [ "$(date +%s)" -lt "$end_time" ]; do
    case "$service_type" in
      "http"|"https")
        if check_http_service "$service_url"; then
          elapsed=$(($(date +%s) - start_time))
          log_info "HTTP service is ready (took ${elapsed}s)"
          return 0
        fi
        ;;
      "tcp")
        if check_tcp_service "$service_host" "$service_port"; then
          elapsed=$(($(date +%s) - start_time))
          log_info "TCP service is ready (took ${elapsed}s)"
          return 0
        fi
        ;;
      "postgres"|"postgresql"|"mysql"|"mariadb"|"mongodb"|"mongo"|"redis")
        if check_database_service "$service_type" "$service_host" "$service_port" "$service_database" "$service_username" "$service_password"; then
          elapsed=$(($(date +%s) - start_time))
          log_info "Database service is ready (took ${elapsed}s)"
          return 0
        fi
        ;;
      "elasticsearch")
        service_url="http://$service_host:$service_port"
        if check_elasticsearch_service "$service_url"; then
          elapsed=$(($(date +%s) - start_time))
          log_info "Elasticsearch service is ready (took ${elapsed}s)"
          return 0
        fi
        ;;
      "rabbitmq")
        service_url="http://$service_host:$service_port"
        if check_rabbitmq_service "$service_url" "$service_username" "$service_password"; then
          elapsed=$(($(date +%s) - start_time))
          log_info "RabbitMQ service is ready (took ${elapsed}s)"
          return 0
        fi
        ;;
      *)
        log_error "Unknown service type: $service_type"
        return 1
        ;;
    esac

    sleep "$interval"
  done

  log_error "Service $service_type at $service_host:$service_port is not ready after ${timeout}s"
  return 1
}

# Wait for multiple services
wait_for_services() {
  local services=("$@")
  local timeout="$DEFAULT_TIMEOUT"
  local interval="$DEFAULT_INTERVAL"
  local parallel=false
  local fail_fast=false

  # Parse options from the end of arguments
  while [[ ${#services[@]} -gt 0 ]]; do
    case "${services[-1]}" in
      --timeout=*)
        timeout="${services[-1]#*=}"
        unset 'services[-1]'
        ;;
      --interval=*)
        interval="${services[-1]#*=}"
        unset 'services[-1]'
        ;;
      --parallel)
        parallel=true
        unset 'services[-1]'
        ;;
      --fail-fast)
        fail_fast=true
        unset 'services[-1]'
        ;;
      *)
        break
        ;;
    esac
  done

  if [ ${#services[@]} -eq 0 ]; then
    log_error "No services specified"
    return 1
  fi

  log_info "Waiting for ${#services[@]} service(s) with timeout ${timeout}s"

  if [ "$parallel" = true ]; then
    # Wait for services in parallel
    local pids=()

    for service in "${services[@]}"; do
      (
        wait_for_service "$service" "$timeout" "$interval"
        echo $? > "/tmp/wait_result_$$_$(echo "$service" | tr '/:' '_')"
      ) &
      pids+=($!)
    done
    
    # Wait for all background processes
    for pid in "${pids[@]}"; do
      wait "$pid"
    done
    
    # Check results
    local failed_services=()
    for service in "${services[@]}"; do
      local result_file
      result_file="/tmp/wait_result_$$_$(echo "$service" | tr '/:' '_')"
      if [ -f "$result_file" ]; then
        local result
        result=$(cat "$result_file")
        rm -f "$result_file"
        
        if [ "$result" -ne 0 ]; then
          failed_services+=("$service")
        fi
      else
        failed_services+=("$service")
      fi
    done
    
    if [ ${#failed_services[@]} -gt 0 ]; then
      log_error "Failed to connect to services: ${failed_services[*]}"
      return 1
    fi
  else
    # Wait for services sequentially
    for service in "${services[@]}"; do
      if ! wait_for_service "$service" "$timeout" "$interval"; then
        if [ "$fail_fast" = true ]; then
          log_error "Failing fast due to service failure: $service"
          return 1
        else
          log_warn "Service failed but continuing: $service"
        fi
      fi
    done
  fi
  
  log_info "All services are ready"
  return 0
}

# Predefined service configurations
load_predefined_services() {
  local config_file="${1:-docker-compose.yml}"
  local services=()
  
  if [ -f "$config_file" ]; then
    log_info "Loading services from $config_file"
    
    # Basic parsing of docker-compose.yml
    # This is a simplified parser and may not cover all cases
    while IFS= read -r line; do
      if [[ "$line" =~ ^[[:space:]]*([a-zA-Z0-9_-]+):[[:space:]]*$ ]]; then
        local service_name="${BASH_REMATCH[1]}"
        
        # Skip non-service sections
        if [[ "$service_name" =~ ^(version|services|volumes|networks)$ ]]; then
          continue
        fi
        
        # Add common service types with default ports
        case "$service_name" in
          *postgresql*|*postgres*)
            services+=("postgres:localhost:5432")
            ;;
          *mariadb*|*mysql*)
            services+=("mysql:localhost:3306")
            ;;
          *redis*)
            services+=("redis:localhost:6379")
            ;;
          *mongo*)
            services+=("mongodb:localhost:27017")
            ;;
          *elasticsearch*)
            services+=("elasticsearch:localhost:9200")
            ;;
          *rabbitmq*)
            services+=("rabbitmq:localhost:15672")
            ;;
          *)
            # Generic HTTP service
            services+=("http://localhost:3000")
            ;;
        esac
      fi
    done < "$config_file"
  fi
  
  printf '%s\n' "${services[@]}"
}

# Help function
show_help() {
  echo "Service Dependency Waiter Script"
  echo "Usage: $0 [services…] [options]"
  echo ""
  echo "Service Formats:"
  echo "  HTTP:   http://host:port or https://host:port"
  echo "  TCP:    tcp:host:port"
  echo "  Database: type:host:port[:database[:username[:password]]]"
  echo ""
  echo "Supported Database Types:"
  echo "  postgres, postgresql, mysql, mariadb, mongodb, mongo, redis"
  echo "  elasticsearch, rabbitmq"
  echo ""
  echo "Options:"
  echo "  --timeout=N     - Timeout in seconds (default: $DEFAULT_TIMEOUT)"
  echo "  --interval=N    - Check interval in seconds (default: $DEFAULT_INTERVAL)"
  echo "  --parallel    - Wait for services in parallel"
  echo "  --fail-fast     - Stop on first service failure"
  echo "  --from-compose  - Load services from docker-compose.yml"
  echo "  --help      - Show this help message"
  echo ""
  echo "Examples:"
  echo "  $0 http://localhost:3000"
  echo "  $0 postgres:localhost:5432:mydb:user:pass"
  echo "  $0 tcp:localhost:6379 http://localhost:8080"
  echo "  $0 --from-compose"
  echo "  $0 redis:localhost:6379 --timeout=60 --parallel"
}

# Main function
main() {
  local services=()
  local from_compose=false
  
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      --help| h)
        show_help
        exit 0
        ;;
      --from-compose)
        from_compose=true
        shift
        ;;
      --timeout=*| -interval=*| -parallel| -fail-fast)
        # These are handled later, just add to services array
        services+=("$1")
        shift
        ;;
      -*)
        log_error "Unknown option: $1"
        show_help
        exit 1
        ;;
      *)
        services+=("$1")
        shift
        ;;
    esac
  done
  
  # Load services from docker-compose if requested
  if [ "$from_compose" = true ]; then
    log_info "Loading services from docker-compose.yml"

    local compose_services
    mapfile -t compose_services < <(load_predefined_services "docker-compose.yml")
    
    if [ ${#compose_services[@]} -gt 0 ]; then
      services=("${compose_services[@]}" "${services[@]}")
      log_info "Loaded ${#compose_services[@]} services from docker-compose.yml"
    else
      log_warn "No services found in docker-compose.yml"
    fi
  fi
  
  # Check if any services specified
  local service_args=()
  for arg in "${services[@]}"; do
    if [[ ! "$arg" =~ ^-- ]]; then
      service_args+=("$arg")
    fi
  done
  
  if [ ${#service_args[@]} -eq 0 ]; then
    log_error "No services specified to wait for"
    show_help
    exit 1
  fi
  
  log_info "Starting service dependency check…"
  log_info "Services to check: ${#service_args[@]}"
  
  # Wait for services
  if wait_for_services "${services[@]}"; then
    log_info "All services are ready, proceeding with tests"
    exit 0
  else
    log_error "Some services are not ready"
    exit 1
  fi
}

# Execute main function
main "$@"
