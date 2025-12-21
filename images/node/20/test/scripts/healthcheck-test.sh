#!/bin/bash
set -euo pipefail

# Progressive health check script for Node.js test image
# Extends dev health check with testing-specific checks

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Configuration
# shellcheck disable=SC2034
readonly TIMEOUT=20
# shellcheck disable=SC2034
readonly MAX_RETRIES=3

# Global variables
EXIT_CODE=0
CHECKS_PASSED=0
CHECKS_TOTAL=0
DEV_HEALTH_PASSED=false

# Logging functions
log_info() {
  echo -e "${GREEN}[TEST-HEALTH]${NC} $1"
}

log_warn() {
  echo -e "${YELLOW}[TEST-HEALTH]${NC} $1" >&2
}

log_error() {
  echo -e "${RED}[TEST-HEALTH]${NC} $1" >&2
}

log_step() {
  echo -e "${BLUE}[TEST-HEALTH]${NC} $1"
}

# Utility functions
increment_check() {
  CHECKS_TOTAL=$((CHECKS_TOTAL + 1))
}

pass_check() {
  CHECKS_PASSED=$((CHECKS_PASSED + 1))
  log_info "✓ $1"
}

fail_check() {
  EXIT_CODE=1
  log_error "✗ $1"
}

# Run dev health check first
run_dev_health_check() {
  log_step "Running development health check…"

  if [ -x "/usr/local/bin/healthcheck-dev.sh" ]; then
    if /usr/local/bin/healthcheck-dev.sh >/dev/null 2>&1; then
      DEV_HEALTH_PASSED=true
      log_info "Development health check passed"
    else
      log_error "Development health check failed"
      EXIT_CODE=1
    fi
  else
    log_warn "Development health check script not found or not executable"
  fi
}

# Testing framework checks
check_testing_frameworks() {
  log_step "Checking testing frameworks…"

  # Check Jest
  increment_check
  if command -v jest >/dev/null 2>&1; then
    local jest_version
    jest_version=$(jest --version 2>/dev/null || echo "")
    if [ -n "$jest_version" ]; then
      pass_check "Jest is installed ($jest_version)"
    else
      fail_check "Jest binary exists but version check failed"
    fi
  else
    fail_check "Jest is not installed"
  fi

  # Check Cypress
  increment_check
  if command -v cypress >/dev/null 2>&1; then
    local cypress_version
    cypress_version=$(cypress --version 2>/dev/null | grep "Cypress package version" | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' || echo "")
    if [ -n "$cypress_version" ]; then
      pass_check "Cypress is installed ($cypress_version)"
    else
      fail_check "Cypress binary exists but version check failed"
    fi
  else
    fail_check "Cypress is not installed"
  fi

  # Check Playwright
  increment_check
  if command -v playwright >/dev/null 2>&1; then
    local playwright_version
    playwright_version=$(playwright --version 2>/dev/null | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' || echo "")
    if [ -n "$playwright_version" ]; then
      pass_check "Playwright is installed ($playwright_version)"
    else
      fail_check "Playwright binary exists but version check failed"
    fi
  else
    fail_check "Playwright is not installed"
  fi

  # Check Mocha
  increment_check
  if command -v mocha >/dev/null 2>&1; then
    local mocha_version
    mocha_version=$(mocha --version 2>/dev/null || echo "")
    if [ -n "$mocha_version" ]; then
      pass_check "Mocha is installed ($mocha_version)"
    else
      fail_check "Mocha binary exists but version check failed"
    fi
  else
    fail_check "Mocha is not installed"
  fi

  # Check Vitest
  increment_check
  if command -v vitest >/dev/null 2>&1; then
    local vitest_version
    vitest_version=$(vitest --version 2>/dev/null | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' || echo "")
    if [ -n "$vitest_version" ]; then
      pass_check "Vitest is installed ($vitest_version)"
    else
      fail_check "Vitest binary exists but version check failed"
    fi
  else
    fail_check "Vitest is not installed"
  fi
}

# Browser and display checks
check_browser_environment() {
  log_step "Checking browser environment…"

  # Check Xvfb (virtual display)
  increment_check
  if command -v Xvfb >/dev/null 2>&1; then
    pass_check "Xvfb is available for headless testing"
  else
    fail_check "Xvfb is not available"
  fi

  # Check Chromium
  increment_check
  if command -v chromium-browser >/dev/null 2>&1 || command -v chromium >/dev/null 2>&1; then
    pass_check "Chromium browser is available"
  else
    fail_check "Chromium browser is not available"
  fi

  # Check Firefox
  increment_check
  if command -v firefox >/dev/null 2>&1; then
    pass_check "Firefox browser is available"
  else
    fail_check "Firefox browser is not available"
  fi

  # Check display environment
  increment_check
  if [ -n "${DISPLAY:-}" ]; then
    pass_check "DISPLAY environment variable is set ($DISPLAY)"
  else
    fail_check "DISPLAY environment variable is not set"
  fi

  # Check X11 directory
  increment_check
  if [ -d "/tmp/.X11-unix" ]; then
    pass_check "X11 socket directory exists"
  else
    fail_check "X11 socket directory not found"
  fi
}

# Testing configuration checks
check_testing_configuration() {
  log_step "Checking testing configuration…"

  # Check Jest config
  increment_check
  if [ -f "/usr/local/etc/jest.config.js" ]; then
    if node -e "require('/usr/local/etc/jest.config.js')" 2>/dev/null; then
      pass_check "Jest configuration is valid"
    else
      fail_check "Jest configuration is invalid"
    fi
  else
    fail_check "Jest configuration not found"
  fi

  # Check Cypress config
  increment_check
  if [ -f "/usr/local/etc/cypress.config.js" ]; then
    if node -e "require('/usr/local/etc/cypress.config.js')" 2>/dev/null; then
      pass_check "Cypress configuration is valid"
    else
      fail_check "Cypress configuration is invalid"
    fi
  else
    fail_check "Cypress configuration not found"
  fi

  # Check test Node.js config
  increment_check
  if [ -f "/usr/local/etc/node-config.json" ]; then
    if node -e "
      const config = JSON.parse(require('fs').readFileSync('/usr/local/etc/node-config.json', 'utf8'));
      if (config.environment !== 'test') {
        process.exit(1);
      }
    " 2>/dev/null; then
      pass_check "Test Node.js configuration is valid"
    else
      fail_check "Test Node.js configuration is invalid"
    fi
  else
    fail_check "Test Node.js configuration not found"
  fi

  # Check NODE_ENV
  increment_check
  if [ "${NODE_ENV:-}" = "test" ]; then
    pass_check "NODE_ENV is set to test"
  else
    fail_check "NODE_ENV is not set to test (current: ${NODE_ENV:-unset})"
  fi
}

# Testing directories and permissions
check_testing_directories() {
  log_step "Checking testing directories…"

  # Check required directories
  local test_dirs=(
    "$HOME/.cache/cypress"
    "$HOME/.cache/playwright"
    "$HOME/.cache/jest"
    "$HOME/test-results"
    "$HOME/coverage"
  )

  increment_check
  local missing_dirs=""
  for dir in "${test_dirs[@]}"; do
    if [ ! -d "$dir" ]; then
      missing_dirs="$missing_dirs $(basename "$dir")"
    fi
  done
  if [ -z "$missing_dirs" ]; then
    pass_check "Testing directories exist"
  else
    fail_check "Missing testing directories:$missing_dirs"
  fi

  # Check directory permissions
  increment_check
  local permission_issues=""
  for dir in "${test_dirs[@]}"; do
    if [ -d "$dir" ] && [ ! -w "$dir" ]; then
      permission_issues="$permission_issues $(basename "$dir")"
    fi
  done
  if [ -z "$permission_issues" ]; then
    pass_check "Testing directory permissions are correct"
  else
    fail_check "Permission issues in directories:$permission_issues"
  fi

  # Check tmp directory
  increment_check
  if [ -w "/tmp" ]; then
    pass_check "Temporary directory is writable"
  else
    fail_check "Temporary directory is not writable"
  fi
}

# Coverage tools checks
check_coverage_tools() {
  log_step "Checking coverage tools…"

  # Check nyc
  increment_check
  if command -v nyc >/dev/null 2>&1; then
    local nyc_version
    nyc_version=$(nyc --version 2>/dev/null || echo "")
    if [ -n "$nyc_version" ]; then
      pass_check "nyc coverage tool is installed ($nyc_version)"
    else
      fail_check "nyc binary exists but version check failed"
    fi
  else
    fail_check "nyc coverage tool is not installed"
  fi

  # Check c8
  increment_check
  if command -v c8 >/dev/null 2>&1; then
    local c8_version
    c8_version=$(c8 --version 2>/dev/null || echo "")
    if [ -n "$c8_version" ]; then
      pass_check "c8 coverage tool is installed ($c8_version)"
    else
      fail_check "c8 binary exists but version check failed"
    fi
  else
    fail_check "c8 coverage tool is not installed"
  fi

  # Check lcov
  increment_check
  if command -v lcov >/dev/null 2>&1; then
    local lcov_version
    lcov_version=$(lcov --version 2>/dev/null | head -n1 || echo "")
    if [ -n "$lcov_version" ]; then
      pass_check "lcov is installed ($lcov_version)"
    else
      fail_check "lcov binary exists but version check failed"
    fi
  else
    fail_check "lcov is not installed"
  fi
}

# Performance testing tools
check_performance_tools() {
  log_step "Checking performance testing tools…"

  # Check Artillery
  increment_check
  if command -v artillery >/dev/null 2>&1; then
    local artillery_version
    artillery_version=$(artillery --version 2>/dev/null || echo "")
    if [ -n "$artillery_version" ]; then
      pass_check "Artillery is installed ($artillery_version)"
    else
      fail_check "Artillery binary exists but version check failed"
    fi
  else
    fail_check "Artillery is not installed"
  fi

  # Check Lighthouse
  increment_check
  if command -v lighthouse >/dev/null 2>&1; then
    local lighthouse_version
    lighthouse_version=$(lighthouse --version 2>/dev/null || echo "")
    if [ -n "$lighthouse_version" ]; then
      pass_check "Lighthouse is installed ($lighthouse_version)"
    else
      fail_check "Lighthouse binary exists but version check failed"
    fi
  else
    fail_check "Lighthouse is not installed"
  fi

  # Check autocannon
  increment_check
  if command -v autocannon >/dev/null 2>&1; then
    local autocannon_version
    autocannon_version=$(autocannon --version 2>/dev/null || echo "")
    if [ -n "$autocannon_version" ]; then
      pass_check "autocannon is installed ($autocannon_version)"
    else
      fail_check "autocannon binary exists but version check failed"
    fi
  else
    fail_check "autocannon is not installed"
  fi
}

# Browser functionality tests
check_browser_functionality() {
  log_step "Checking browser functionality…"

  # Test Chromium launch
  increment_check
  if timeout 10 chromium-browser --version >/dev/null 2>&1; then
    pass_check "Chromium browser launches successfully"
  else
    fail_check "Chromium browser fails to launch"
  fi

  # Test Firefox launch
  increment_check
  if timeout 10 firefox --version >/dev/null 2>&1; then
    pass_check "Firefox browser launches successfully"
  else
    fail_check "Firefox browser fails to launch"
  fi

  # Test Playwright browsers
  increment_check
  if npx playwright --version >/dev/null 2>&1; then
    pass_check "Playwright browsers are accessible"
  else
    fail_check "Playwright browsers are not accessible"
  fi
}

# Memory and performance checks
check_testing_performance() {
  log_step "Checking testing performance…"

  # Check available memory for testing
  increment_check
  local memory_info
  if memory_info=$(cat /proc/meminfo 2>/dev/null); then
    local mem_available
    mem_available=$(echo "$memory_info" | grep MemAvailable | awk '{print $2}')
    if [ "${mem_available:-0}" -gt 512000 ]; then # 500MB
      pass_check "Sufficient memory for testing (${mem_available}KB)"
    else
      fail_check "Insufficient memory for testing (${mem_available}KB)"
    fi
  else
    fail_check "Could not read memory information"
  fi

  # Check disk space for test artifacts
  increment_check
  local disk_space
  disk_space=$(df /tmp 2>/dev/null | tail -1 | awk '{print $4}' || echo "0")
  if [ "${disk_space:-0}" -gt 1048576 ]; then # 1GB
    pass_check "Sufficient disk space for test artifacts (${disk_space}KB)"
  else
    fail_check "Insufficient disk space for test artifacts (${disk_space}KB)"
  fi

  # Check file descriptor limits
  increment_check
  local fd_limit
  fd_limit=$(ulimit -n 2>/dev/null || echo "0")
  if [ "${fd_limit:-0}" -ge 4096 ]; then
    pass_check "File descriptor limit is adequate for testing ($fd_limit)"
  else
    fail_check "File descriptor limit is too low for testing ($fd_limit)"
  fi
}

# Testing script availability
check_testing_scripts() {
  log_step "Checking testing scripts…"

  local scripts=(
    "/usr/local/bin/run-all-tests.sh"
    "/usr/local/bin/run-coverage.sh"
    "/usr/local/bin/run-e2e.sh"
    "/usr/local/bin/run-performance.sh"
    "/usr/local/bin/wait-for-services.sh"
  )

  increment_check
  local missing_scripts=""
  for script in "${scripts[@]}"; do
    if [ ! -x "$script" ]; then
      missing_scripts="$missing_scripts $(basename "$script")"
    fi
  done
  if [ -z "$missing_scripts" ]; then
    pass_check "All testing scripts are available and executable"
  else
    fail_check "Missing or non-executable scripts:$missing_scripts"
  fi
}

# Main health check function
perform_testing_health_check() {
  log_info "Starting testing environment health check…"
  log_info "Timestamp: $(date -Iseconds)"
  log_info "Container uptime: $(cat /proc/uptime | cut -d' ' -f1)s"
  log_info "Testing mode: ${NODE_ENV:-unset}"

  # Run dev health check first
  run_dev_health_check

  # Run testing-specific checks
  check_testing_frameworks
  check_browser_environment
  check_testing_configuration
  check_testing_directories
  check_coverage_tools
  check_performance_tools
  check_browser_functionality
  check_testing_performance
  check_testing_scripts

  # Summary
  log_info "Testing health check completed"
  log_info "Checks passed: $CHECKS_PASSED/$CHECKS_TOTAL"

  if [ $EXIT_CODE -eq 0 ] && [ "$DEV_HEALTH_PASSED" = true ]; then
    log_info "Overall status: HEALTHY (Testing Ready)"
  else
    log_error "Overall status: UNHEALTHY"
    log_error "Failed checks: $((CHECKS_TOTAL - CHECKS_PASSED))/$CHECKS_TOTAL"
    if [ "$DEV_HEALTH_PASSED" = false ]; then
      log_error "Development health check failed"
    fi
  fi

  return $EXIT_CODE
}

# Execute testing health check
perform_testing_health_check
