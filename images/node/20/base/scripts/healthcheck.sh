#!/bin/bash
set -euo pipefail

# Progressive health check script for Node.js base image
# Performs comprehensive health checks with progressive complexity

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# Configuration
# shellcheck disable=SC2034
readonly TIMEOUT=10
# shellcheck disable=SC2034
readonly MAX_RETRIES=3
# shellcheck disable=SC2034
readonly CHECK_INTERVAL=1

# Global variables
EXIT_CODE=0
CHECKS_PASSED=0
CHECKS_TOTAL=0

# Logging functions
log_info() {
  printf "${GREEN}[HEALTH]${NC} %s\n" "$1"
}

log_warn() {
  printf "${YELLOW}[HEALTH]${NC} %s\n" "$1" >&2
}

log_error() {
  printf "${RED}[HEALTH]${NC} %s\n" "$1" >&2
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

# Basic system checks
check_system_health() {
  log_info "Performing system health checks…"

  # Check if we're running as the correct user
  increment_check
  if [ "$(whoami)" = "node" ]; then
    pass_check "Running as node user"
  else
    fail_check "Not running as node user (current: $(whoami))"
  fi

  # Check working directory
  increment_check
  if [ "$(pwd)" = "/app" ]; then
    pass_check "Working directory is /app"
  else
    fail_check "Working directory is not /app (current: $(pwd))"
  fi

  # Check file system permissions
  increment_check
  if [ -w "/app" ] && [ -w "/tmp/.npm" ]; then
    pass_check "Required directories are writable"
  else
    fail_check "Required directories are not writable"
  fi

  # Check memory usage
  increment_check
  local memory_info
  if memory_info=$(cat /proc/meminfo 2>/dev/null); then
    local mem_available
    mem_available=$(echo "$memory_info" | grep MemAvailable | awk '{print $2}')
    if [ "${mem_available:-0}" -gt 51200 ]; then # 50MB
      pass_check "Sufficient memory available (${mem_available}KB)"
    else
      fail_check "Insufficient memory available (${mem_available}KB)"
    fi
  else
    fail_check "Could not read memory information"
  fi
}

# Node.js installation checks
check_nodejs_installation() {
  log_info "Checking Node.js installation…"

  # Check Node.js binary
  increment_check
  if command -v node >/dev/null 2>&1; then
    local node_version
    node_version=$(node --version 2>/dev/null || echo "")
    if [ -n "$node_version" ]; then
      pass_check "Node.js is installed ($node_version)"
    else
      fail_check "Node.js binary exists but version check failed"
    fi
  else
    fail_check "Node.js is not installed or not in PATH"
  fi

  # Check npm binary
  increment_check
  if command -v npm >/dev/null 2>&1; then
    local npm_version
    npm_version=$(npm --version 2>/dev/null || echo "")
    if [ -n "$npm_version" ]; then
      pass_check "npm is installed ($npm_version)"
    else
      fail_check "npm binary exists but version check failed"
    fi
  else
    fail_check "npm is not installed or not in PATH"
  fi

  # Test Node.js execution
  increment_check
  if echo "console.log('health-check')" | node 2>/dev/null | grep -q "health-check"; then
    pass_check "Node.js execution test passed"
  else
    fail_check "Node.js execution test failed"
  fi

  # Test npm configuration
  increment_check
  if npm config get registry >/dev/null 2>&1; then
    pass_check "npm configuration is accessible"
  else
    fail_check "npm configuration is not accessible"
  fi
}

# Configuration validation
check_configuration() {
  log_info "Validating configuration…"

  # Check npm cache directory
  increment_check
  local npm_cache
  npm_cache=$(npm config get cache 2>/dev/null || echo "")
  if [ -n "$npm_cache" ] && [ -d "$npm_cache" ] && [ -w "$npm_cache" ]; then
    pass_check "npm cache directory is accessible ($npm_cache)"
  else
    fail_check "npm cache directory is not accessible ($npm_cache)"
  fi

  # Check Node.js configuration
  increment_check
  if [ -f "/usr/local/etc/node-config.json" ]; then
    if node -e "JSON.parse(require('fs').readFileSync('/usr/local/etc/node-config.json', 'utf8'))" 2>/dev/null; then
      pass_check "Node.js configuration file is valid"
    else
      fail_check "Node.js configuration file is invalid JSON"
    fi
  else
    log_warn "Node.js configuration file not found (optional)"
  fi

  # Check npm configuration
  increment_check
  if [ -f "/etc/npmrc" ]; then
    pass_check "npm configuration file exists"
  else
    fail_check "npm configuration file not found"
  fi

  # Check environment variables
  increment_check
  local required_vars="NODE_ENV NODE_VERSION"
  local missing_vars=""
  for var in $required_vars; do
    if ! env | grep -q "^${var}="; then
      missing_vars="$missing_vars $var"
    fi
  done
  if [ -z "$missing_vars" ]; then
    pass_check "Required environment variables are set"
  else
    fail_check "Missing environment variables:$missing_vars"
  fi
}

# Network connectivity checks
check_network() {
  log_info "Checking network connectivity…"

  # Check if we can resolve DNS
  increment_check
  if nslookup registry.npmjs.org >/dev/null 2>&1; then
    pass_check "DNS resolution is working"
  else
    fail_check "DNS resolution failed"
  fi

  # Check npm registry connectivity (if network is available)
  increment_check
  if timeout 5 npm ping >/dev/null 2>&1; then
    pass_check "npm registry is reachable"
  else
    log_warn "npm registry is not reachable (may be offline)"
    # Don't fail this check as network might be intentionally restricted
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
  fi
}

# Application-specific checks
check_application() {
  log_info "Checking application state…"

  # Check if package.json exists and is valid
  increment_check
  if [ -f "/app/package.json" ]; then
    if node -e "JSON.parse(require('fs').readFileSync('/app/package.json', 'utf8'))" 2>/dev/null; then
      pass_check "package.json is valid"

      # Check if dependencies are installed in production
      increment_check
      if [ "$NODE_ENV" = "production" ]; then
        if [ -d "/app/node_modules" ]; then
          pass_check "Dependencies are installed"
        else
          fail_check "Dependencies are not installed in production mode"
        fi
      else
        log_info "Skipping dependency check (not in production mode)"
        CHECKS_PASSED=$((CHECKS_PASSED + 1))
      fi
    else
      fail_check "package.json is invalid JSON"
      CHECKS_PASSED=$((CHECKS_PASSED + 1)) # Skip dependency check
    fi
  else
    log_info "No package.json found (not an application container)"
    CHECKS_PASSED=$((CHECKS_PASSED + 2)) # Skip package.json and dependency checks
  fi
}

# Performance checks
check_performance() {
  log_info "Checking performance metrics…"

  # Check Node.js memory usage
  increment_check
  local memory_test
  memory_test=$(node -e "
    const used = process.memoryUsage();
    console.log(JSON.stringify(used));
  " 2>/dev/null || echo "{}")

  if echo "$memory_test" | grep -q "heapUsed"; then
    pass_check "Node.js memory metrics are accessible"
  else
    fail_check "Node.js memory metrics are not accessible"
  fi

  # Check process limits
  increment_check
  if ulimit -n >/dev/null 2>&1; then
    local fd_limit
    fd_limit=$(ulimit -n)
    if [ "$fd_limit" -ge 1024 ]; then
      pass_check "File descriptor limit is adequate ($fd_limit)"
    else
      fail_check "File descriptor limit is too low ($fd_limit)"
    fi
  else
    fail_check "Could not check file descriptor limits"
  fi
}

# Main health check function
perform_health_check() {
  log_info "Starting comprehensive health check…"
  log_info "Timestamp: $(date -Iseconds)"
  log_info "Container uptime: $(cat /proc/uptime | cut -d' ' -f1)s"

  # Run all check categories
  check_system_health
  check_nodejs_installation
  check_configuration
  check_network
  check_application
  check_performance

  # Summary
  log_info "Health check completed"
  log_info "Checks passed: $CHECKS_PASSED/$CHECKS_TOTAL"

  if [ $EXIT_CODE -eq 0 ]; then
    log_info "Overall status: HEALTHY"
  else
    log_error "Overall status: UNHEALTHY"
    log_error "Failed checks: $((CHECKS_TOTAL - CHECKS_PASSED))/$CHECKS_TOTAL"
  fi

  return $EXIT_CODE
}

# Execute health check
perform_health_check
