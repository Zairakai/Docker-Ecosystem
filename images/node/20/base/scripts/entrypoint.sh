#!/bin/bash
set -euo pipefail

# Container entrypoint script for Node.js base image
# Handles initialization, configuration, and process management

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# Logging functions
log_info() {
  printf "${GREEN}[INFO]${NC} %s - %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$1"
}

log_warn() {
  printf "${YELLOW}[WARN]${NC} %s - %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >&2
}

log_error() {
  printf "${RED}[ERROR]${NC} %s - %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >&2
}

# Signal handlers
cleanup() {
  log_info "Received signal, shutting down gracefully…"
  if [ -n "${PID:-}" ]; then
    kill -TERM "$PID" 2>/dev/null || true
    wait "$PID" 2>/dev/null || true
  fi
  exit 0
}

trap cleanup TERM INT

# Environment validation
validate_environment() {
  log_info "Validating environment…"

  # Check Node.js installation
  if ! command -v node >/dev/null 2>&1; then
    log_error "Node.js is not installed or not in PATH"
    exit 1
  fi

  # Check npm installation
  if ! command -v npm >/dev/null 2>&1; then
    log_error "npm is not installed or not in PATH"
    exit 1
  fi

  # Verify Node.js version
  local node_version
  node_version=$(node --version 2>/dev/null | sed 's/v//')
  if [ -z "$node_version" ]; then
    log_error "Could not determine Node.js version"
    exit 1
  fi

  log_info "Node.js version: $node_version"
  log_info "npm version: $(npm --version 2>/dev/null || echo 'unknown')"

  # Validate required directories
  for dir in "/app" "/tmp/.npm"; do
    if [ ! -d "$dir" ]; then
      log_error "Required directory does not exist: $dir"
      exit 1
    fi
    if [ ! -w "$dir" ]; then
      log_error "Directory is not writable: $dir"
      exit 1
    fi
  done

  log_info "Environment validation completed successfully"
}

# Configuration setup
setup_configuration() {
  log_info "Setting up configuration…"

  # Load production configuration if available
  if [ -f "/usr/local/etc/node-config.json" ]; then
    log_info "Production configuration found"
    export NODE_CONFIG_PATH="/usr/local/etc/node-config.json"
  fi

  # Set Node.js options based on environment
  if [ -z "${NODE_OPTIONS:-}" ]; then
    export NODE_OPTIONS="--max-old-space-size=512"
  fi

  # Configure npm cache
  if [ -d "/tmp/.npm" ]; then
    npm config set cache /tmp/.npm --global 2>/dev/null || true
  fi

  # Set timezone if specified
  if [ -n "${TZ:-}" ]; then
    log_info "Setting timezone to: $TZ"
    export TZ
  fi

  log_info "Configuration setup completed"
}

# Application initialization
initialize_application() {
  log_info "Initializing application…"

  # Change to working directory
  cd /app

  # Check if package.json exists in production mode
  if [ "$NODE_ENV" = "production" ] && [ -f "package.json" ]; then
    log_info "package.json found, checking dependencies…"

    # Install production dependencies if node_modules doesn't exist
    if [ ! -d "node_modules" ]; then
      log_info "Installing production dependencies…"
      npm ci --only=production --silent 2>/dev/null || {
        log_warn "npm ci failed, falling back to npm install"
        npm install --only=production --silent 2>/dev/null || {
          log_error "Failed to install dependencies"
          exit 1
        }
      }
    else
      log_info "Dependencies already installed"
    fi
  fi

  log_info "Application initialization completed"
}

# Health check setup
setup_health_check() {
  log_info "Setting up health check…"

  # Health check script is made executable during image build (Dockerfile)
  # No chmod needed here as we run as non-root user
  if [ -f "/usr/local/bin/healthcheck.sh" ]; then
    log_info "Health check script configured"
  else
    log_warn "Health check script not found"
  fi
}

# Process management
start_process() {
  local cmd="$1"
  shift

  log_info "Starting process: $cmd $*"

  # Execute the command based on type
  case "$cmd" in
    "node")
      if [ $# -eq 0 ]; then
        # Interactive mode
        exec node
      else
        # Run specific script
        exec node "$@"
      fi
      ;;
    "npm")
      exec npm "$@"
      ;;
    "bash"|"sh"|"ash")
      exec "$cmd" "$@"
      ;;
    *)
      # Try to execute as-is
      if command -v "$cmd" >/dev/null 2>&1; then
        exec "$cmd" "$@"
      else
        log_error "Unknown command: $cmd"
        exit 1
      fi
      ;;
  esac
}

# Main execution flow
main() {
  log_info "Starting Node.js base container…"
  log_info "Node.js version: $(node --version)"
  log_info "Environment: ${NODE_ENV:-development}"
  log_info "User: $(whoami)"
  log_info "Working directory: $(pwd)"

  # Run initialization steps
  validate_environment
  setup_configuration
  setup_health_check
  initialize_application

  # Handle arguments
  if [ $# -eq 0 ]; then
    log_info "No command specified, starting interactive Node.js session"
    start_process "node"
  else
    log_info "Executing command: $*"
    start_process "$@"
  fi
}

# Execute main function with all arguments
main "$@"
