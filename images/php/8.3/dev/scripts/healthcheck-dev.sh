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

# Logging functions
log() {
  echo -e "${BLUE}[HEALTHCHECK-DEV]${NC} $1"
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

# Run base health check first
check_base_health() {
  log "Running base health check…"

  if [ -f "/usr/local/bin/healthcheck.sh" ]; then
    if /usr/local/bin/healthcheck.sh; then
      success "Base health check passed"
      return 0
    else
      error "Base health check failed"
      return 1
    fi
  else
    warn "Base health check script not found"
    return 0
  fi
}

# Check Xdebug extension
check_xdebug() {
  log "Checking Xdebug extension…"

  if php -m | grep -q "xdebug"; then
    success "Xdebug extension is loaded"

    # Check Xdebug configuration
    XDEBUG_MODE=$(php -r "echo ini_get('xdebug.mode');")
    log "Xdebug mode: $XDEBUG_MODE"

    if [ -n "$XDEBUG_MODE" ] && [ "$XDEBUG_MODE" != "off" ]; then
      success "Xdebug is properly configured"
      return 0
    else
      warn "Xdebug is loaded but disabled"
      return 0
    fi
  else
    error "Xdebug extension is not loaded"
    return 1
  fi
}

# Check development tools
check_dev_tools() {
  log "Checking development tools…"

  local tools_ok=0

  # Check Composer
  if command -v composer >/dev/null 2>&1; then
    success "Composer is available"
  else
    error "Composer is not available"
    tools_ok=1
  fi

  # Check Git
  if command -v git >/dev/null 2>&1; then
    success "Git is available"
  else
    warn "Git is not available"
  fi

  # Check Node.js (optional)
  if command -v node >/dev/null 2>&1; then
    success "Node.js is available: $(node --version)"
  else
    log "Node.js is not available (optional)"
  fi

  # Check npm (optional)
  if command -v npm >/dev/null 2>&1; then
    success "npm is available: $(npm --version)"
  else
    log "npm is not available (optional)"
  fi

  return $tools_ok
}

# Check Redis extension (if enabled)
check_redis() {
  log "Checking Redis extension…"

  if php -m | grep -q "redis"; then
    success "Redis extension is loaded"
    return 0
  else
    warn "Redis extension is not loaded"
    return 0
  fi
}

# Check ImageMagick extension (if enabled)
check_imagick() {
  log "Checking ImageMagick extension…"

  if php -m | grep -q "imagick"; then
    success "ImageMagick extension is loaded"
    return 0
  else
    warn "ImageMagick extension is not loaded"
    return 0
  fi
}

# Check log directories and permissions
check_dev_directories() {
  log "Checking development directories…"

  local dirs_ok=0

  # Check Xdebug log directory
  if [ -d "/var/log/xdebug" ] && [ -w "/var/log/xdebug" ]; then
    success "Xdebug log directory is writable"
  else
    error "Xdebug log directory is not writable"
    dirs_ok=1
  fi

  # Check PHP log directory
  if [ -d "/var/log/php" ] && [ -w "/var/log/php" ]; then
    success "PHP log directory is writable"
  else
    error "PHP log directory is not writable"
    dirs_ok=1
  fi

  # Check temporary directories
  if [ -w "/tmp" ]; then
    success "Temporary directory is writable"
  else
    error "Temporary directory is not writable"
    dirs_ok=1
  fi

  return $dirs_ok
}

# Note: Quality tools (phpstan, php-cs-fixer, phpunit, etc.) should be installed
# per-project via composer.json, not globally. This allows each project to use
# specific versions and configurations.

# Check PHP development configuration
check_php_dev_config() {
  log "Checking PHP development configuration…"

  local display_errors
  local error_reporting
  local memory_limit
  display_errors=$(php -r "echo ini_get('display_errors') ? 'On' : 'Off';")
  error_reporting=$(php -r "echo error_reporting();")
  memory_limit=$(php -r "echo ini_get('memory_limit');")

  log "Development settings:"
  echo "  - display_errors: $display_errors"
  echo "  - error_reporting: $error_reporting"
  echo "  - memory_limit: $memory_limit"

  if [ "$display_errors" = "On" ]; then
    success "Development error display is enabled"
  else
    warn "Development error display is disabled"
  fi

  return 0
}

# Main health check function
main() {
  log "Starting PHP 8.3 Development Health Check…"

  local exit_code=0

  # Run all health checks
  if ! check_base_health; then
    exit_code=1
  fi

  if ! check_xdebug; then
    exit_code=1
  fi

  if ! check_dev_tools; then
    exit_code=1
  fi

  if ! check_redis; then
    # Redis check is optional, don't fail
    true
  fi

  if ! check_imagick; then
    # ImageMagick check is optional, don't fail
    true
  fi

  if ! check_dev_directories; then
    exit_code=1
  fi

  check_php_dev_config

  # Summary
  if [ $exit_code -eq 0 ]; then
    success "All critical development health checks passed"
  else
    error "Some critical health checks failed"
  fi

  exit $exit_code
}

# Run main health check
main "$@"
