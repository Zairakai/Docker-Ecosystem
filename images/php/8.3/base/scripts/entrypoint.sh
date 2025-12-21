#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
  printf '%b\n' "${BLUE}[ENTRYPOINT]${NC} $1"
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

# Main entrypoint logic
main() {
  log "Starting PHP 8.3 Base Container…"

  # Verify PHP installation
  if ! command -v php >/dev/null 2>&1; then
    error "PHP is not installed or not in PATH"
    exit 1
  fi

  # Check PHP version
  PHP_VERSION=$(php -r "echo PHP_VERSION;")
  log "PHP Version: $PHP_VERSION"

  # Validate PHP-FPM configuration
  if ! php-fpm -t >/dev/null 2>&1; then
    error "PHP-FPM configuration test failed"
    php-fpm -t
    exit 1
  fi

  success "PHP-FPM configuration is valid"

  # Create necessary directories
  mkdir -p /tmp/opcache
  chown -R www:www /tmp/opcache

  # Create runtime directories
  mkdir -p /var/run/php
  chown -R www:www /var/run/php

  # Set proper permissions for application directory
  if [ -d "/var/www/html" ]; then
    chown -R www:www /var/www/html
    log "Set ownership of /var/www/html to www:www"
  fi

  # Execute pre-start hooks if they exist
  if [ -d "/docker-entrypoint-init.d" ]; then
    log "Executing pre-start hooks…"
    for f in /docker-entrypoint-init.d/*; do
      case "$f" in
        *.sh)
          if [ -x "$f" ]; then
            log "Running $f"
            "$f"
          else
            warn "Skipping $f, not executable"
          fi
          ;;
        *)
          warn "Ignoring $f"
          ;;
      esac
    done
  fi

  success "Container initialization completed"

  # Execute the main command
  log "Executing: $*"
  exec "$@"
}

# Run main function with all arguments
main "$@"
