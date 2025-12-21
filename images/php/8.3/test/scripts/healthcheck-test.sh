#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
  echo -e "${BLUE}[HEALTHCHECK-TEST]${NC} $1"
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

# Run development health check first
check_dev_health() {
  log "Running development health check…"

  if [ -f "/usr/local/bin/healthcheck-dev.sh" ]; then
    if /usr/local/bin/healthcheck-dev.sh; then
      success "Development health check passed"
      return 0
    else
      error "Development health check failed"
      return 1
    fi
  else
    warn "Development health check script not found"
    return 0
  fi
}

# Check PCOV extension
check_pcov() {
  log "Checking PCOV extension…"

  if php -m | grep -q "pcov"; then
    success "PCOV extension is loaded"

    local pcov_enabled
    pcov_enabled=$(php -r "echo extension_loaded('pcov') && ini_get('pcov.enabled') ? '1' : '0';")
    if [ "$pcov_enabled" = "1" ]; then
      success "PCOV is enabled for coverage collection"
    else
      log "PCOV is loaded but disabled (can be enabled when needed)"
    fi
    return 0
  else
    error "PCOV extension is not loaded"
    return 1
  fi
}

# Check XHProf extension
check_xhprof() {
  log "Checking XHProf extension…"

  if php -m | grep -q "xhprof"; then
    success "XHProf extension is loaded"

    local xhprof_enabled
    xhprof_enabled=$(php -r "echo extension_loaded('xhprof') && ini_get('xhprof.enable') ? '1' : '0';")
    log "XHProf profiling status: $([ "$xhprof_enabled" = "1" ] && echo "enabled" || echo "disabled")"
    return 0
  else
    error "XHProf extension is not loaded"
    return 1
  fi
}

# Check browser tools for E2E testing
check_browsers() {
  log "Checking browser tools…"

  local browsers_ok=0

  # Check Chromium
  if command -v chromium-browser >/dev/null 2>&1; then
    success "Chromium browser is available: $(chromium-browser --version 2>/dev/null | head -1)"
  else
    error "Chromium browser is not available"
    browsers_ok=1
  fi

  # Check ChromeDriver
  if command -v chromedriver >/dev/null 2>&1; then
    success "ChromeDriver is available: $(chromedriver --version 2>/dev/null | head -1)"
  else
    warn "ChromeDriver is not available"
  fi

  # Check Firefox
  if command -v firefox >/dev/null 2>&1; then
    success "Firefox browser is available"
  else
    warn "Firefox browser is not available"
  fi

  return $browsers_ok
}

# Check Python testing tools
check_python_tools() {
  log "Checking Python testing tools…"

  local python_ok=0

  # Check Python
  if command -v python3 >/dev/null 2>&1; then
    success "Python 3 is available: $(python3 --version)"
  else
    error "Python 3 is not available"
    python_ok=1
  fi

  # Check pip
  if command -v pip3 >/dev/null 2>&1; then
    success "pip3 is available"
  else
    warn "pip3 is not available"
  fi

  # Check essential Python packages
  local python_packages=("selenium" "pytest" "requests")
  for package in "${python_packages[@]}"; do
    if python3 -c "import $package" 2>/dev/null; then
      success "Python package available: $package"
    else
      warn "Python package missing: $package"
    fi
  done

  return $python_ok
}

# Check testing directories and permissions
check_test_directories() {
  log "Checking testing directories…"

  local dirs_ok=0

  # List of required testing directories
  local test_dirs=(
    "/var/log/testing"
    "/var/log/coverage"
    "/var/log/profiling"
    "/var/log/performance"
    "/tmp/test-results"
    "/tmp/coverage-reports"
    "/tmp/profiling-data"
  )

  for dir in "${test_dirs[@]}"; do
    if [ -d "$dir" ] && [ -w "$dir" ]; then
      success "Testing directory is writable: $dir"
    else
      error "Testing directory is not writable: $dir"
      dirs_ok=1
    fi
  done

  return $dirs_ok
}

# Note: Testing packages (phpunit, phpstan, infection, etc.) should be installed
# via project composer.json, not globally. This allows each project to use
# specific versions and configurations.

# Check testing environment variables
check_test_environment() {
  log "Checking testing environment…"

  # Display testing environment configuration
  log "Testing environment configuration:"
  echo "  - TESTING_MODE: ${TESTING_MODE:-not set}"
  echo "  - PCOV_ENABLED: ${PCOV_ENABLED:-not set}"
  echo "  - XHPROF_ENABLED: ${XHPROF_ENABLED:-not set}"
  echo "  - CHROME_BIN: ${CHROME_BIN:-not set}"
  echo "  - FIREFOX_BIN: ${FIREFOX_BIN:-not set}"

  if [ "${TESTING_MODE}" = "true" ]; then
    success "Testing mode is enabled"
  else
    warn "Testing mode is not explicitly enabled"
  fi

  return 0
}

# Check PHP testing configuration
check_php_test_config() {
  log "Checking PHP testing configuration…"

  local opcache_enabled
  local memory_limit
  local max_execution_time
  opcache_enabled=$(php -r "echo ini_get('opcache.enable') ? 'On' : 'Off';")
  memory_limit=$(php -r "echo ini_get('memory_limit');")
  max_execution_time=$(php -r "echo ini_get('max_execution_time');")

  log "PHP testing settings:"
  echo "  - opcache.enable: $opcache_enabled"
  echo "  - memory_limit: $memory_limit"
  echo "  - max_execution_time: $max_execution_time"

  if [ "$opcache_enabled" = "Off" ]; then
    success "OPcache is disabled for testing (good)"
  else
    warn "OPcache is enabled (may cache old code during testing)"
  fi

  return 0
}

# Main health check function
main() {
  log "Starting PHP 8.3 Testing Health Check…"

  local exit_code=0

  # Run all health checks
  if ! check_dev_health; then
    exit_code=1
  fi

  if ! check_pcov; then
    exit_code=1
  fi

  if ! check_xhprof; then
    exit_code=1
  fi

  if ! check_browsers; then
    exit_code=1
  fi

  if ! check_python_tools; then
    exit_code=1
  fi

  if ! check_test_directories; then
    exit_code=1
  fi

  check_test_environment
  check_php_test_config

  # Summary
  if [ $exit_code -eq 0 ]; then
    success "All critical testing health checks passed"
  else
    error "Some critical testing health checks failed"
  fi

  exit $exit_code
}

# Run main health check
main "$@"
