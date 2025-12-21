#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Health check configuration
PHP_FPM_HOST=${PHP_FPM_HOST:-localhost}
PHP_FPM_PORT=${PHP_FPM_PORT:-9000}
TIMEOUT=${HEALTH_CHECK_TIMEOUT:-3}

# Logging functions
log() {
  printf '%b\n' "${BLUE}[HEALTHCHECK]${NC} $1"
}

error() {
  printf '%b\n' "${RED}[ERROR]${NC} $1" >&2
}

success() {
  printf '%b\n' "${GREEN}[SUCCESS]${NC} $1"
}

warn() {
  printf '%b\n' "${YELLOW}[WARNING]${NC} $1"
}

# Check if PHP-FPM is responding
check_php_fpm() {
  log "Checking PHP-FPM on $PHP_FPM_HOST:$PHP_FPM_PORT…"

  # Use cgi-fcgi to test PHP-FPM
  if command -v cgi-fcgi >/dev/null 2>&1; then
    if timeout "$TIMEOUT" cgi-fcgi -bind -connect "$PHP_FPM_HOST:$PHP_FPM_PORT" 2>/dev/null; then
      return 0
    fi
  fi

  # Fallback: Check if the port is listening
  if nc -z "$PHP_FPM_HOST" "$PHP_FPM_PORT" 2>/dev/null; then
    return 0
  fi

  return 1
}

# Check PHP process
check_php_process() {
  log "Checking PHP-FPM process…"

  if pgrep -f "php-fpm" >/dev/null 2>&1; then
    return 0
  fi

  return 1
}

# Check system resources
check_resources() {
  log "Checking system resources…"

  # Check available memory (basic check)
  if [ -r /proc/meminfo ]; then
    AVAILABLE_MEMORY=$(awk '/MemAvailable/ {print $2}' /proc/meminfo 2>/dev/null || echo "0")
    if [ "$AVAILABLE_MEMORY" -lt 10240 ]; then  # Less than 10MB
      warn "Low memory detected: ${AVAILABLE_MEMORY}KB"
    fi
  fi

  # Check disk space for temp directory
  if [ -d /tmp ]; then
    TEMP_USAGE=$(df /tmp 2>/dev/null | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "$TEMP_USAGE" -gt 90 ]; then
      warn "High disk usage in /tmp: ${TEMP_USAGE}%"
    fi
  fi

  return 0
}

# Check PHP installation and extensions (one-shot mode)
check_php_installation() {
  log "Checking PHP installation…"

  if ! command -v php >/dev/null 2>&1; then
    error "PHP binary not found"
    return 1
  fi

  PHP_VERSION=$(php -r "echo PHP_VERSION;" 2>/dev/null)
  if [ -z "$PHP_VERSION" ]; then
    error "PHP not functional"
    return 1
  fi

  success "PHP $PHP_VERSION is installed and functional"

  # Check critical extensions
  log "Checking PHP extensions…"
  REQUIRED_EXTENSIONS="bcmath curl gd intl mbstring pdo pdo_mysql"
  MISSING=""

  for ext in $REQUIRED_EXTENSIONS; do
    if ! php -m 2>/dev/null | grep -qi "^$ext$"; then
      MISSING="$MISSING $ext"
    fi
  done

  # Special check for Zend OPcache (different naming in php -m)
  if ! php -m 2>/dev/null | grep -qi "Zend OPcache"; then
    MISSING="$MISSING opcache"
  fi

  if [ -n "$MISSING" ]; then
    error "Missing extensions:$MISSING"
    return 1
  fi

  success "All required PHP extensions are loaded"
  return 0
}

# Main health check function
main() {
  EXIT_CODE=0

  # Detect mode: daemon (PHP-FPM running) or one-shot (direct test)
  if pgrep -f "php-fpm" >/dev/null 2>&1; then
    log "Running in DAEMON mode (PHP-FPM active)"

    # Check 1: PHP-FPM process
    if ! check_php_process; then
      error "PHP-FPM process not running"
      EXIT_CODE=1
    else
      success "PHP-FPM process is running"
    fi

    # Check 2: PHP-FPM network connectivity
    if ! check_php_fpm; then
      error "PHP-FPM not responding on $PHP_FPM_HOST:$PHP_FPM_PORT"
      EXIT_CODE=1
    else
      success "PHP-FPM is responding"
    fi

    # Check 3: System resources (warnings only)
    check_resources
  else
    log "Running in ONE-SHOT mode (direct test)"

    # One-shot mode: just verify PHP installation and extensions
    if ! check_php_installation; then
      EXIT_CODE=1
    fi
  fi

  # Summary
  if [ $EXIT_CODE -eq 0 ]; then
    success "All health checks passed"
  else
    error "Health check failed"
  fi

  exit $EXIT_CODE
}

# Install netcat if not available (for port checking)
if ! command -v nc >/dev/null 2>&1; then
  if command -v apk >/dev/null 2>&1; then
    apk add --no-cache netcat-openbsd >/dev/null 2>&1 || true
  fi
fi

# Run main health check
main "$@"
