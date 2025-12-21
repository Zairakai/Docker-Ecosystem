#!/bin/bash
set -euo pipefail

# Progressive health check script for Node.js dev image
# Extends base health check with development-specific checks

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Configuration
# shellcheck disable=SC2034
readonly TIMEOUT=15
# shellcheck disable=SC2034
readonly MAX_RETRIES=3

# Global variables
EXIT_CODE=0
CHECKS_PASSED=0
CHECKS_TOTAL=0
BASE_HEALTH_PASSED=false

# Logging functions
log_info() {
  echo -e "${GREEN}[DEV-HEALTH]${NC} $1"
}

log_warn() {
  echo -e "${YELLOW}[DEV-HEALTH]${NC} $1" >&2
}

log_error() {
  echo -e "${RED}[DEV-HEALTH]${NC} $1" >&2
}

log_step() {
  echo -e "${BLUE}[DEV-HEALTH]${NC} $1"
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

# Run base health check first
run_base_health_check() {
  log_step "Running base health check…"

  if [ -x "/usr/local/bin/healthcheck.sh" ]; then
    if /usr/local/bin/healthcheck.sh >/dev/null 2>&1; then
      BASE_HEALTH_PASSED=true
      log_info "Base health check passed"
    else
      log_error "Base health check failed"
      EXIT_CODE=1
    fi
  else
    log_warn "Base health check script not found or not executable"
  fi
}

# Development tools checks
check_development_tools() {
  log_step "Checking development tools…"

  # Check Yarn
  increment_check
  if command -v yarn >/dev/null 2>&1; then
    local yarn_version
    yarn_version=$(yarn --version 2>/dev/null || echo "")
    if [ -n "$yarn_version" ]; then
      pass_check "Yarn is installed ($yarn_version)"
    else
      fail_check "Yarn binary exists but version check failed"
    fi
  else
    fail_check "Yarn is not installed"
  fi

  # Check pnpm
  increment_check
  if command -v pnpm >/dev/null 2>&1; then
    local pnpm_version
    pnpm_version=$(pnpm --version 2>/dev/null || echo "")
    if [ -n "$pnpm_version" ]; then
      pass_check "pnpm is installed ($pnpm_version)"
    else
      fail_check "pnpm binary exists but version check failed"
    fi
  else
    fail_check "pnpm is not installed"
  fi

  # Check TypeScript
  increment_check
  if command -v tsc >/dev/null 2>&1; then
    local ts_version
    ts_version=$(tsc --version 2>/dev/null | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' || echo "")
    if [ -n "$ts_version" ]; then
      pass_check "TypeScript is installed ($ts_version)"
    else
      fail_check "TypeScript binary exists but version check failed"
    fi
  else
    fail_check "TypeScript is not installed"
  fi

  # Check ts-node
  increment_check
  if command -v ts-node >/dev/null 2>&1; then
    local tsnode_version
    tsnode_version=$(ts-node --version 2>/dev/null | head -n1 | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' || echo "")
    if [ -n "$tsnode_version" ]; then
      pass_check "ts-node is installed ($tsnode_version)"
    else
      fail_check "ts-node binary exists but version check failed"
    fi
  else
    fail_check "ts-node is not installed"
  fi

  # Check nodemon
  increment_check
  if command -v nodemon >/dev/null 2>&1; then
    local nodemon_version
    nodemon_version=$(nodemon --version 2>/dev/null || echo "")
    if [ -n "$nodemon_version" ]; then
      pass_check "nodemon is installed ($nodemon_version)"
    else
      fail_check "nodemon binary exists but version check failed"
    fi
  else
    fail_check "nodemon is not installed"
  fi

  # Note: ESLint and Prettier should be installed per-project, not globally
  # Projects manage their own versions and configurations
}

# Development configuration checks
check_development_config() {
  log_step "Checking development configuration…"

  # Check development Node.js config
  increment_check
  if [ -f "/usr/local/etc/node-config.json" ]; then
    if node -e "
      const config = JSON.parse(require('fs').readFileSync('/usr/local/etc/node-config.json', 'utf8'));
      if (config.environment !== 'development') {
        process.exit(1);
      }
    " 2>/dev/null; then
      pass_check "Development Node.js configuration is valid"
    else
      fail_check "Development Node.js configuration is invalid"
    fi
  else
    fail_check "Development Node.js configuration not found"
  fi

  # Note: ESLint config should be managed per-project

  # Check user configurations
  increment_check
  local user_configs=("$HOME/.bashrc" "$HOME/.npmrc" "$HOME/.gitconfig")
  local missing_configs=""
  for config in "${user_configs[@]}"; do
    if [ ! -f "$config" ]; then
      missing_configs="$missing_configs $(basename "$config")"
    fi
  done
  if [ -z "$missing_configs" ]; then
    pass_check "User configuration files exist"
  else
    fail_check "Missing user configurations:$missing_configs"
  fi

  # Check Yarn configuration
  increment_check
  if [ -f "$HOME/.config/yarn/config" ]; then
    pass_check "Yarn configuration exists"
  else
    fail_check "Yarn configuration not found"
  fi
}

# Development environment checks
check_development_environment() {
  log_step "Checking development environment…"

  # Check NODE_ENV
  increment_check
  if [ "${NODE_ENV:-}" = "development" ]; then
    pass_check "NODE_ENV is set to development"
  else
    fail_check "NODE_ENV is not set to development (current: ${NODE_ENV:-unset})"
  fi

  # Check debug port availability
  increment_check
  if netstat -ln 2>/dev/null | grep -q ":9229"; then
    log_warn "Debug port 9229 is already in use"
    pass_check "Debug port status checked (in use)"
  else
    pass_check "Debug port 9229 is available"
  fi

  # Check development directories
  increment_check
  local dev_dirs=("$HOME/.npm" "$HOME/.cache/yarn" "$HOME/.local/bin")
  local missing_dirs=""
  for dir in "${dev_dirs[@]}"; do
    if [ ! -d "$dir" ]; then
      missing_dirs="$missing_dirs $(basename "$dir")"
    fi
  done
  if [ -z "$missing_dirs" ]; then
    pass_check "Development directories exist"
  else
    fail_check "Missing development directories:$missing_dirs"
  fi

  # Check file permissions
  increment_check
  local writable_dirs=("$HOME" "$HOME/.npm" "$HOME/.cache" "/tmp")
  local permission_issues=""
  for dir in "${writable_dirs[@]}"; do
    if [ -d "$dir" ] && [ ! -w "$dir" ]; then
      permission_issues="$permission_issues $(basename "$dir")"
    fi
  done
  if [ -z "$permission_issues" ]; then
    pass_check "Directory permissions are correct"
  else
    fail_check "Permission issues in directories:$permission_issues"
  fi
}

# Build tools checks
check_build_tools() {
  log_step "Checking build tools…"

  # Check build dependencies
  increment_check
  if command -v make >/dev/null 2>&1 && command -v g++ >/dev/null 2>&1; then
    pass_check "Build tools are available"
  else
    fail_check "Build tools are missing"
  fi

  # Check Python (for native modules)
  increment_check
  if command -v python3 >/dev/null 2>&1; then
    local python_version
    python_version=$(python3 --version 2>&1 | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' || echo "")
    if [ -n "$python_version" ]; then
      pass_check "Python3 is available ($python_version)"
    else
      fail_check "Python3 version check failed"
    fi
  else
    fail_check "Python3 is not available"
  fi

  # Check Git
  increment_check
  if command -v git >/dev/null 2>&1; then
    local git_version
    git_version=$(git --version 2>/dev/null | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' || echo "")
    if [ -n "$git_version" ]; then
      pass_check "Git is available ($git_version)"
    else
      fail_check "Git version check failed"
    fi
  else
    fail_check "Git is not available"
  fi
}

# Package management checks
check_package_management() {
  log_step "Checking package management…"

  # Test npm functionality
  increment_check
  if npm config list >/dev/null 2>&1; then
    pass_check "npm configuration is accessible"
  else
    fail_check "npm configuration is not accessible"
  fi

  # Test Yarn functionality
  increment_check
  if yarn config current >/dev/null 2>&1; then
    pass_check "Yarn configuration is accessible"
  else
    fail_check "Yarn configuration is not accessible"
  fi

  # Test pnpm functionality
  increment_check
  if pnpm config list >/dev/null 2>&1; then
    pass_check "pnpm configuration is accessible"
  else
    fail_check "pnpm configuration is not accessible"
  fi

  # Check cache directories
  increment_check
  local npm_cache
  npm_cache=$(npm config get cache 2>/dev/null || echo "")
  if [ -n "$npm_cache" ] && [ -d "$npm_cache" ] && [ -w "$npm_cache" ]; then
    pass_check "npm cache directory is accessible"
  else
    fail_check "npm cache directory is not accessible"
  fi

  increment_check
  local yarn_cache
  yarn_cache=$(yarn cache dir 2>/dev/null || echo "")
  if [ -n "$yarn_cache" ] && [ -d "$yarn_cache" ] && [ -w "$yarn_cache" ]; then
    pass_check "Yarn cache directory is accessible"
  else
    fail_check "Yarn cache directory is not accessible"
  fi
}

# Development server checks
check_development_server() {
  log_step "Checking development server capabilities…"

  # Check if we can create a simple HTTP server
  increment_check
  local test_result
  test_result=$(timeout 5 node -e "
    const http = require('http');
    const server = http.createServer((req, res) => {
      res.writeHead(200, {'Content-Type': 'text/plain'});
      res.end('OK');
    });
    server.listen(0, () => {
      console.log('Server started on port', server.address().port);
      server.close();
    });
  " 2>/dev/null || echo "failed")

  if echo "$test_result" | grep -q "Server started"; then
    pass_check "HTTP server functionality works"
  else
    fail_check "HTTP server functionality failed"
  fi

  # Check WebSocket support
  increment_check
  if node -e "require('ws')" 2>/dev/null; then
    log_info "WebSocket support available (if ws module is installed)"
  else
    log_info "WebSocket support requires ws module installation"
  fi
  pass_check "WebSocket capability checked"

  # Check process management
  increment_check
  if command -v pm2 >/dev/null 2>&1; then
    pass_check "Process manager (PM2) is available"
  else
    fail_check "Process manager (PM2) is not available"
  fi
}

# Performance checks
check_development_performance() {
  log_step "Checking development performance…"

  # Check memory allocation
  increment_check
  local memory_test
  memory_test=$(node -e "
    const used = process.memoryUsage();
    const available = used.heapTotal - used.heapUsed;
    console.log(JSON.stringify({
      heapUsed: Math.round(used.heapUsed / 1024 / 1024),
      heapTotal: Math.round(used.heapTotal / 1024 / 1024),
      available: Math.round(available / 1024 / 1024)
    }));
  " 2>/dev/null || echo "{}")

  if echo "$memory_test" | grep -q "heapUsed"; then
    local heap_used
    heap_used=$(echo "$memory_test" | node -e "
      const data = JSON.parse(require('fs').readFileSync('/dev/stdin', 'utf8'));
      console.log(data.heapUsed);
    " 2>/dev/null || echo "0")
    pass_check "Memory allocation working (heap used: ${heap_used}MB)"
  else
    fail_check "Memory allocation test failed"
  fi

  # Check file system performance
  increment_check
  local write_test="/tmp/healthcheck-write-test"
  if echo "test" > "$write_test" 2>/dev/null && [ -f "$write_test" ]; then
    rm -f "$write_test"
    pass_check "File system write operations work"
  else
    fail_check "File system write operations failed"
  fi

  # Check module loading performance
  increment_check
  local module_test
  module_test=$(timeout 10 node -e "
    const start = Date.now();
    require('fs');
    require('path');
    require('util');
    require('crypto');
    const end = Date.now();
    console.log(end - start);
  " 2>/dev/null || echo "timeout")

  if [ "$module_test" != "timeout" ] && [ "$module_test" -lt 5000 ]; then
    pass_check "Module loading performance is good (${module_test}ms)"
  else
    fail_check "Module loading performance is poor or timed out"
  fi
}

# Main health check function
perform_development_health_check() {
  log_info "Starting development environment health check…"
  log_info "Timestamp: $(date -Iseconds)"
  log_info "Container uptime: $(cat /proc/uptime | cut -d' ' -f1)s"
  log_info "Development mode: ${NODE_ENV:-unset}"

  # Run base health check first
  run_base_health_check

  # Run development-specific checks
  check_development_tools
  check_development_config
  check_development_environment
  check_build_tools
  check_package_management
  check_development_server
  check_development_performance

  # Summary
  log_info "Development health check completed"
  log_info "Checks passed: $CHECKS_PASSED/$CHECKS_TOTAL"

  if [ $EXIT_CODE -eq 0 ] && [ "$BASE_HEALTH_PASSED" = true ]; then
    log_info "Overall status: HEALTHY (Development Ready)"
  else
    log_error "Overall status: UNHEALTHY"
    log_error "Failed checks: $((CHECKS_TOTAL - CHECKS_PASSED))/$CHECKS_TOTAL"
    if [ "$BASE_HEALTH_PASSED" = false ]; then
      log_error "Base health check failed"
    fi
  fi

  return $EXIT_CODE
}

# Execute development health check
perform_development_health_check
