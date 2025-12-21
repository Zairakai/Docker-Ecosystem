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
  echo -e "${BLUE}[DEV-SETUP]${NC} $1"
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

# Setup development environment
setup_development_environment() {
  log "Setting up development environment…"

  # Create log directories
  mkdir -p /var/log/xdebug /var/log/php
  chown -R www:www /var/log/xdebug /var/log/php

  # Ensure proper permissions for development
  if [ -d "/var/www/html" ]; then
    chown -R www:www /var/www/html
  fi

  # Create cache directories
  mkdir -p /tmp/php-session /tmp/php-uploads
  chown -R www:www /tmp/php-session /tmp/php-uploads

  success "Development directories created"
}

# Configure Xdebug for the current environment
configure_xdebug() {
  log "Configuring Xdebug for development…"

  # Set Xdebug client host based on environment
  if [ -n "$XDEBUG_CLIENT_HOST" ]; then
    log "Setting Xdebug client host to: $XDEBUG_CLIENT_HOST"
    echo "xdebug.client_host=$XDEBUG_CLIENT_HOST" >> /usr/local/etc/php/conf.d/xdebug.ini
  fi

  # Set Xdebug client port if specified
  if [ -n "$XDEBUG_CLIENT_PORT" ]; then
    log "Setting Xdebug client port to: $XDEBUG_CLIENT_PORT"
    echo "xdebug.client_port=$XDEBUG_CLIENT_PORT" >> /usr/local/etc/php/conf.d/xdebug.ini
  fi

  # Set IDE key if specified
  if [ -n "$XDEBUG_IDE_KEY" ]; then
    log "Setting Xdebug IDE key to: $XDEBUG_IDE_KEY"
    echo "xdebug.idekey=$XDEBUG_IDE_KEY" >> /usr/local/etc/php/conf.d/xdebug.ini
  fi

  # Configure Xdebug mode
  XDEBUG_MODE="${XDEBUG_MODE:-develop,debug}"
  log "Setting Xdebug mode to: $XDEBUG_MODE"
  echo "xdebug.mode=$XDEBUG_MODE" >> /usr/local/etc/php/conf.d/xdebug.ini

  success "Xdebug configuration completed"
}

# Setup Composer for development
setup_composer() {
  log "Setting up Composer for development…"

  # Configure Composer home directory
  export COMPOSER_HOME="/home/www/.composer"
  mkdir -p "$COMPOSER_HOME"
  chown -R www:www "$COMPOSER_HOME"

  # Configure Composer cache
  export COMPOSER_CACHE_DIR="/tmp/composer-cache"
  mkdir -p "$COMPOSER_CACHE_DIR"
  chown -R www:www "$COMPOSER_CACHE_DIR"

  # Set Composer configuration
  composer config --global process-timeout 2000
  composer config --global cache-ttl 86400

  # Add global bin directory to PATH
  if [ -d "$COMPOSER_HOME/vendor/bin" ]; then
    export PATH="$COMPOSER_HOME/vendor/bin:$PATH"
  fi

  success "Composer development setup completed"
}

# Auto-install dependencies if composer.json exists
auto_install_dependencies() {
  if [ -f "/var/www/html/composer.json" ] && [ "${AUTO_INSTALL_DEPS:-true}" = "true" ]; then
    log "Found composer.json, auto-installing dependencies…"
    cd /var/www/html
    if /usr/local/bin/composer-install.sh; then
      success "Dependencies installed automatically"
    else
      warn "Automatic dependency installation failed"
    fi
  fi
}

# Setup development tools
setup_dev_tools() {
  log "Setting up development tools…"

  # Configure Git if in development mode
  if [ "${SETUP_GIT:-false}" = "true" ]; then
    if [ -n "$GIT_USER_NAME" ] && [ -n "$GIT_USER_EMAIL" ]; then
      git config --global user.name "$GIT_USER_NAME"
      git config --global user.email "$GIT_USER_EMAIL"
      log "Git configured with name: $GIT_USER_NAME, email: $GIT_USER_EMAIL"
    fi
  fi

  # Setup Node.js/npm if needed
  if [ "${SETUP_NODE:-false}" = "true" ]; then
    npm config set cache /tmp/npm-cache
    log "Node.js/npm configured"
  fi

  success "Development tools setup completed"
}

# Display development environment info
show_dev_info() {
  log "Development Environment Information:"
  echo "  - PHP Version: $(php -r 'echo PHP_VERSION;')"
  echo "  - Xdebug Version: $(php -r 'echo phpversion("xdebug");')"
  echo "  - Composer Version: $(composer --version --no-ansi)"

  if command -v node >/dev/null 2>&1; then
    echo "  - Node.js Version: $(node --version)"
  fi

  if command -v npm >/dev/null 2>&1; then
    echo "  - npm Version: $(npm --version)"
  fi

  # Show Xdebug configuration
  echo ""
  log "Xdebug Configuration:"
  php -r "
    if (extension_loaded('xdebug')) {
      echo '  - Mode: ' . ini_get('xdebug.mode') . PHP_EOL;
      echo '  - Client Host: ' . ini_get('xdebug.client_host') . PHP_EOL;
      echo '  - Client Port: ' . ini_get('xdebug.client_port') . PHP_EOL;
      echo '  - IDE Key: ' . ini_get('xdebug.idekey') . PHP_EOL;
    }
    else {
      echo '  - Xdebug not loaded' . PHP_EOL;
    }
  "
}

# Main setup function
main() {
  log "Starting PHP 8.3 Development Container Setup…"

  # Run the base entrypoint first
  if [ -f "/usr/local/bin/entrypoint.sh" ]; then
    log "Running base entrypoint…"
    source /usr/local/bin/entrypoint.sh
  fi

  # Development-specific setup
  setup_development_environment
  configure_xdebug
  setup_composer
  setup_dev_tools
  auto_install_dependencies
  show_dev_info

  success "Development environment setup completed"

  # Execute the main command
  log "Executing: $*"
  exec "$@"
}

# Handle script arguments
case "$1" in
  --help|-h)
    echo "Usage: $0 [command]"
    echo ""
    echo "Environment variables:"
    echo "  XDEBUG_CLIENT_HOST     Xdebug client host (default: host.docker.internal)"
    echo "  XDEBUG_CLIENT_PORT     Xdebug client port (default: 9003)"
    echo "  XDEBUG_IDE_KEY         IDE key for Xdebug (default: PHPSTORM)"
    echo "  XDEBUG_MODE            Xdebug mode (default: develop,debug)"
    echo "  AUTO_INSTALL_DEPS      Auto-install composer deps (default: true)"
    echo "  SETUP_GIT              Setup Git configuration (default: false)"
    echo "  SETUP_NODE             Setup Node.js configuration (default: false)"
    echo "  GIT_USER_NAME          Git user name"
    echo "  GIT_USER_EMAIL         Git user email"
    exit 0
    ;;
  *)
    main "$@"
    ;;
esac
