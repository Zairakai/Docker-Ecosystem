#!/bin/bash
set -eo pipefail

# MySQL 8.4 Custom Entrypoint Script
# Handles initialization, security, and configuration

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
  echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] [MYSQL-ENTRYPOINT]${NC} $1"
}

log_error() {
  echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] [MYSQL-ENTRYPOINT] ERROR:${NC} $1" >&2
}

log_warning() {
  echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] [MYSQL-ENTRYPOINT] WARNING:${NC} $1"
}

log_success() {
  echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] [MYSQL-ENTRYPOINT] SUCCESS:${NC} $1"
}

# Function to check if MySQL is running
mysql_is_running() {
  mysqladmin ping --silent --user=root --password="$MYSQL_ROOT_PASSWORD" 2>/dev/null
}

# Function to wait for MySQL to be ready
wait_for_mysql() {
  local timeout=60
  local count=0

  log "Waiting for MySQL to be ready…"

  while ! mysql_is_running; do
    if [ $count -ge $timeout ]; then
      log_error "MySQL failed to start within $timeout seconds"
      exit 1
    fi
    count=$((count + 1))
    sleep 1
  done

  log_success "MySQL is ready"
}

# Function to load credentials from files
load_credentials() {
  if [ -f "$MYSQL_ROOT_PASSWORD_FILE" ]; then
    export MYSQL_ROOT_PASSWORD
    MYSQL_ROOT_PASSWORD="$(cat "$MYSQL_ROOT_PASSWORD_FILE")"
    log "Loaded root password from file"
  fi

  if [ -f "$MYSQL_USER_FILE" ]; then
    export MYSQL_USER
    MYSQL_USER="$(cat "$MYSQL_USER_FILE")"
    log "Loaded user from file"
  fi

  if [ -f "$MYSQL_PASSWORD_FILE" ]; then
    export MYSQL_PASSWORD
    MYSQL_PASSWORD="$(cat "$MYSQL_PASSWORD_FILE")"
    log "Loaded user password from file"
  fi
}

# Function to set up log rotation
setup_log_rotation() {
  log "Setting up log rotation…"

  cat > /etc/logrotate.d/mysql << EOF
/var/log/mysql/*.log {
  daily
  rotate 7
  compress
  delaycompress
  missingok
  notifempty
  create 640 mysql mysql
  postrotate
    if test -x /usr/bin/mysqladmin && mysqladmin ping --silent --user=root --password="$MYSQL_ROOT_PASSWORD" 2>/dev/null; then
      mysqladmin flush-logs --user=root --password="$MYSQL_ROOT_PASSWORD"
    fi
  endscript
}
EOF

  log_success "Log rotation configured"
}

# Function to optimize MySQL configuration based on available memory
optimize_configuration() {
  local total_mem
  total_mem=$(grep MemTotal /proc/meminfo | awk '{print $2}')
  local total_mem_mb
  total_mem_mb=$((total_mem / 1024))

  log "Detected ${total_mem_mb}MB of total memory"

  # Adjust InnoDB buffer pool size based on available memory
  if [ $total_mem_mb -lt 1024 ]; then
    # Less than 1GB RAM
    export INNODB_BUFFER_POOL_SIZE="128M"
    log_warning "Low memory detected, setting InnoDB buffer pool to 128M"
  elif [ $total_mem_mb -lt 2048 ]; then
    # Less than 2GB RAM
    export INNODB_BUFFER_POOL_SIZE="512M"
    log "Setting InnoDB buffer pool to 512M"
  elif [ $total_mem_mb -lt 4096 ]; then
    # Less than 4GB RAM
    export INNODB_BUFFER_POOL_SIZE="1G"
    log "Setting InnoDB buffer pool to 1G"
  else
    # 4GB+ RAM
    local buffer_size
    buffer_size=$((total_mem_mb * 70 / 100))
    export INNODB_BUFFER_POOL_SIZE="${buffer_size}M"
    log "Setting InnoDB buffer pool to ${buffer_size}M (70% of available memory)"
  fi
}

# Function to setup monitoring user
setup_monitoring_user() {
  if [ -n "$MYSQL_MONITORING_USER" ] && [ -n "$MYSQL_MONITORING_PASSWORD" ]; then
    log "Setting up monitoring user…"

    mysql --user=root --password="$MYSQL_ROOT_PASSWORD" <<-EOF
      CREATE USER IF NOT EXISTS '${MYSQL_MONITORING_USER}'@'%' IDENTIFIED BY '${MYSQL_MONITORING_PASSWORD}';
      GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO '${MYSQL_MONITORING_USER}'@'%';
      FLUSH PRIVILEGES;
EOF

    log_success "Monitoring user created"
  fi
}

# Function to create application database and user
setup_application_db() {
  if [ -n "$MYSQL_DATABASE" ] && [ -n "$MYSQL_USER" ] && [ -n "$MYSQL_PASSWORD" ]; then
    log "Setting up application database and user…"

    mysql --user=root --password="$MYSQL_ROOT_PASSWORD" <<-EOF
      CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\` CHARACTER SET ${MYSQL_CHARSET:-utf8mb4} COLLATE ${MYSQL_COLLATION:-utf8mb4_unicode_ci};
      CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
      GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
      FLUSH PRIVILEGES;
EOF

    log_success "Application database and user created"
  fi
}

# Function to run initialization scripts
run_init_scripts() {
  if [ -d "/docker-entrypoint-initdb.d" ]; then
    log "Running initialization scripts…"

    for f in /docker-entrypoint-initdb.d/*; do
      case "$f" in
        *.sh)
          if [ -x "$f" ]; then
            log "Running $f"
            "$f"
          else
            log "Sourcing $f"
            # shellcheck source=/dev/null
            . "$f"
          fi
          ;;
        *.sql)
          log "Running $f"
          mysql --user=root --password="$MYSQL_ROOT_PASSWORD" < "$f"
          ;;
        *.sql.gz)
          log "Running $f"
          gunzip -c "$f" | mysql --user=root --password="$MYSQL_ROOT_PASSWORD"
          ;;
        *)
          log_warning "Ignoring $f"
          ;;
      esac
    done

    log_success "Initialization scripts completed"
  fi
}

# Main execution
main() {
  log "Starting MySQL 8.4 custom entrypoint…"

  # Load credentials from files if they exist
  load_credentials

  # Optimize configuration based on available resources
  optimize_configuration

  # Check if this is the first run
  if [ ! -d "/var/lib/mysql/mysql" ]; then
    log "First run detected, initializing database…"

    # Ensure proper ownership
    chown -R mysql:mysql /var/lib/mysql
    chown -R mysql:mysql /var/log/mysql

    # Initialize database
    mysqld --initialize-insecure --user=mysql --datadir=/var/lib/mysql

    # Start MySQL in the background for initial setup
    mysqld --user=mysql --daemonize --pid-file=/var/run/mysqld/mysqld.pid

    # Wait for MySQL to be ready
    wait_for_mysql

    # Set root password if provided
    if [ -n "$MYSQL_ROOT_PASSWORD" ]; then
      log "Setting root password…"
      mysql --user=root <<-EOF
        ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
        CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
        GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;
        FLUSH PRIVILEGES;
EOF
      log_success "Root password set"
    fi

    # Setup application database and user
    setup_application_db

    # Setup monitoring user
    setup_monitoring_user

    # Run initialization scripts
    run_init_scripts

    # Stop the background MySQL process
    mysqladmin shutdown --user=root --password="$MYSQL_ROOT_PASSWORD"

    log_success "Database initialization completed"
  else
    log "Database already initialized"
  fi

  # Setup log rotation
  setup_log_rotation

  # Ensure proper ownership before starting
  chown -R mysql:mysql /var/lib/mysql
  chown -R mysql:mysql /var/log/mysql
  chown -R mysql:mysql /var/run/mysqld

  log "Starting MySQL server…"

  # Start MySQL with proper signal handling
  # Always run mysqld as mysql user for security
  if [ "$1" = 'mysqld' ]; then
    exec mysqld --user=mysql
  else
    exec "$@"
  fi
}

# Handle signals gracefully
trap 'log "Received shutdown signal, stopping MySQL…"; mysqladmin shutdown --user=root --password="$MYSQL_ROOT_PASSWORD" 2>/dev/null || true; exit 0' SIGTERM SIGINT

# Run main function
main "$@"
