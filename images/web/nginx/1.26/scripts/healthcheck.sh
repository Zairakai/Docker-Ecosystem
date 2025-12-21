#!/bin/bash

# Nginx health check script
# This script performs comprehensive health checks for nginx

set -e

# Configuration
NGINX_PID_FILE="/var/run/nginx.pid"
HEALTH_ENDPOINT="${HEALTH_ENDPOINT:-http://localhost/health}"
SSL_HEALTH_ENDPOINT="${SSL_HEALTH_ENDPOINT:-https://localhost/health}"
TIMEOUT="${HEALTH_TIMEOUT:-10}"
MAX_RETRIES="${HEALTH_MAX_RETRIES:-3}"
CHECK_SSL="${CHECK_SSL:-false}"

# Function to log messages
log() {
  echo "[HEALTH] $(date +'%Y-%m-%d %H:%M:%S') $1"
}

# Function to check if nginx process is running
check_process() {
  if [[ -f "$NGINX_PID_FILE" ]]; then
    local pid
    pid=$(cat "$NGINX_PID_FILE")
    if kill -0 "$pid" 2>/dev/null; then
      log "Nginx process (PID: $pid) is running"
      return 0
    else
      log "ERROR: Nginx PID file exists but process is not running"
      return 1
    fi
  else
    log "ERROR: Nginx PID file not found"
    return 1
  fi
}

# Function to check HTTP endpoint
check_http_endpoint() {
  local endpoint="$1"
  local protocol="${endpoint%%://*}"
  local retry=0

  while [[ $retry -lt $MAX_RETRIES ]]; do
    if [[ "$protocol" == "https" ]]; then
      # For HTTPS, use curl with insecure flag for self-signed certificates
      if curl -f -s -k --max-time "$TIMEOUT" "$endpoint" >/dev/null 2>&1; then
        log "HTTP health check passed for $endpoint"
        return 0
      fi
    else
      # For HTTP
      if curl -f -s --max-time "$TIMEOUT" "$endpoint" >/dev/null 2>&1; then
        log "HTTP health check passed for $endpoint"
        return 0
      fi
    fi

    retry=$((retry + 1))
    if [[ $retry -lt $MAX_RETRIES ]]; then
      log "HTTP health check failed for $endpoint (attempt $retry/$MAX_RETRIES), retrying…"
      sleep 1
    fi
  done

  log "ERROR: HTTP health check failed for $endpoint after $MAX_RETRIES attempts"
  return 1
}

# Function to check nginx configuration
check_config() {
  if nginx -t >/dev/null 2>&1; then
    log "Nginx configuration is valid"
    return 0
  else
    log "ERROR: Nginx configuration is invalid"
    return 1
  fi
}

# Function to check nginx status page
check_status_page() {
  local status_url="http://localhost/nginx_status"

  if curl -f -s --max-time "$TIMEOUT" "$status_url" | grep -q "Active connections"; then
    log "Nginx status page is accessible"
    return 0
  else
    log "WARNING: Nginx status page is not accessible (this may be expected)"
    return 0  # Don't fail health check for this
  fi
}

# Function to check SSL certificate validity (if SSL is enabled)
check_ssl_certificate() {
  if [[ "$CHECK_SSL" == "true" ]]; then
    local cert_file="${SSL_CERTIFICATE:-/etc/nginx/ssl/server.crt}"

    if [[ -f "$cert_file" ]]; then
      # Check if certificate is not expired
      if openssl x509 -in "$cert_file" -noout -checkend 86400 >/dev/null 2>&1; then
        log "SSL certificate is valid and not expiring within 24 hours"
        return 0
      else
        log "WARNING: SSL certificate is expiring within 24 hours or is invalid"
        return 1
      fi
    else
      log "WARNING: SSL certificate file not found at $cert_file"
      return 1
    fi
  fi

  return 0
}

# Function to check disk space for logs
check_disk_space() {
  local log_dir="/var/log/nginx"
  local threshold="${DISK_THRESHOLD:-90}"

  if [[ -d "$log_dir" ]]; then
    local usage
    usage=$(df "$log_dir" | awk 'NR==2 {print $5}' | sed 's/%//')
    if [[ $usage -gt $threshold ]]; then
      log "WARNING: Disk usage for $log_dir is ${usage}% (threshold: ${threshold}%)"
      return 1
    else
      log "Disk usage for $log_dir is ${usage}% (within threshold)"
      return 0
    fi
  fi

  return 0
}

# Function to check memory usage
check_memory_usage() {
  local threshold="${MEMORY_THRESHOLD:-90}"
  local usage
  usage=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')

  if [[ $usage -gt $threshold ]]; then
    log "WARNING: Memory usage is ${usage}% (threshold: ${threshold}%)"
    return 1
  else
    log "Memory usage is ${usage}% (within threshold)"
    return 0
  fi
}

# Function to run comprehensive health checks
run_health_checks() {
  local exit_code=0

  log "Starting comprehensive health checks…"

  # Check if nginx process is running
  if ! check_process; then
    exit_code=1
  fi

  # Check nginx configuration
  if ! check_config; then
    exit_code=1
  fi

  # Check HTTP endpoint
  if ! check_http_endpoint "$HEALTH_ENDPOINT"; then
    exit_code=1
  fi

  # Check HTTPS endpoint if SSL is enabled
  if [[ "$CHECK_SSL" == "true" ]]; then
    if ! check_http_endpoint "$SSL_HEALTH_ENDPOINT"; then
      exit_code=1
    fi

    if ! check_ssl_certificate; then
      exit_code=1
    fi
  fi

  # Check status page
  check_status_page

  # Check disk space
  if ! check_disk_space; then
    # Don't fail health check for disk space, just warn
    log "WARNING: Disk space check failed but continuing…"
  fi

  # Check memory usage
  if ! check_memory_usage; then
    # Don't fail health check for memory usage, just warn
    log "WARNING: Memory usage check failed but continuing…"
  fi

  if [[ $exit_code -eq 0 ]]; then
    log "All critical health checks passed"
  else
    log "One or more critical health checks failed"
  fi

  return $exit_code
}

# Main execution
case "${1:-health}" in
  "health"|"")
    run_health_checks
    ;;
  "process")
    check_process
    ;;
  "config")
    check_config
    ;;
  "http")
    check_http_endpoint "$HEALTH_ENDPOINT"
    ;;
  "ssl")
    check_ssl_certificate
    ;;
  "status")
    check_status_page
    ;;
  "disk")
    check_disk_space
    ;;
  "memory")
    check_memory_usage
    ;;
  *)
    echo "Usage: $0 {health|process|config|http|ssl|status|disk|memory}"
    echo "  health  - Run all health checks (default)"
    echo "  process - Check if nginx process is running"
    echo "  config  - Check nginx configuration validity"
    echo "  http    - Check HTTP endpoint"
    echo "  ssl     - Check SSL certificate"
    echo "  status  - Check nginx status page"
    echo "  disk    - Check disk space"
    echo "  memory  - Check memory usage"
    exit 1
    ;;
esac
