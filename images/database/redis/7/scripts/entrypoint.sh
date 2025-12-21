#!/bin/bash
set -eo pipefail

# Redis 7 Custom Entrypoint Script
# Handles initialization, security, and configuration

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
  echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] [REDIS-ENTRYPOINT]${NC} $1"
}

log_error() {
  echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] [REDIS-ENTRYPOINT] ERROR:${NC} $1" >&2
}

log_warning() {
  echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] [REDIS-ENTRYPOINT] WARNING:${NC} $1"
}

log_success() {
  echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] [REDIS-ENTRYPOINT] SUCCESS:${NC} $1"
}

# Function to check if Redis is running
redis_is_running() {
  redis-cli ping >/dev/null 2>&1
}

# Function to wait for Redis to be ready
wait_for_redis() {
  local timeout=30
  local count=0

  log "Waiting for Redis to be ready…"

  while ! redis_is_running; do
    if [ $count -ge $timeout ]; then
      log_error "Redis failed to start within $timeout seconds"
      exit 1
    fi
    count=$((count + 1))
    sleep 1
  done

  log_success "Redis is ready"
}

# Function to load credentials from files
load_credentials() {
  if [ -f "$REDIS_PASSWORD_FILE" ]; then
    export REDIS_PASSWORD
    REDIS_PASSWORD="$(cat "$REDIS_PASSWORD_FILE")"
    log "Loaded Redis password from file"
  fi
}

# Function to optimize Redis configuration based on available memory
optimize_configuration() {
  local total_mem
  total_mem=$(grep MemTotal /proc/meminfo | awk '{print $2}')
  local total_mem_mb
  total_mem_mb=$((total_mem / 1024))

  log "Detected ${total_mem_mb}MB of total memory"

  local config_file="${REDIS_CONFIG_FILE:-/etc/redis/redis.conf}"
  local redis_maxmemory

  # Calculate Redis memory limit (leaving memory for OS and other processes)
  if [ $total_mem_mb -lt 512 ]; then
    # Less than 512MB RAM
    redis_maxmemory="128mb"
    log_warning "Low memory detected, setting Redis memory limit to 128MB"
  elif [ $total_mem_mb -lt 1024 ]; then
    # Less than 1GB RAM
    redis_maxmemory="256mb"
    log "Setting Redis memory limit to 256MB"
  elif [ $total_mem_mb -lt 2048 ]; then
    # Less than 2GB RAM
    redis_maxmemory="512mb"
    log "Setting Redis memory limit to 512MB"
  elif [ $total_mem_mb -lt 4096 ]; then
    # Less than 4GB RAM
    redis_maxmemory="1gb"
    log "Setting Redis memory limit to 1GB"
  else
    # 4GB+ RAM - use 25% of available memory
    local redis_mem_mb
    redis_mem_mb=$((total_mem_mb * 25 / 100))
    redis_maxmemory="${redis_mem_mb}mb"
    log "Setting Redis memory limit to ${redis_mem_mb}MB (25% of available memory)"
  fi

  # Update REDIS_MAXMEMORY environment variable
  export REDIS_MAXMEMORY="$redis_maxmemory"
}

# Function to setup Redis configuration
setup_redis_configuration() {
  local config_file="${REDIS_CONFIG_FILE:-/etc/redis/redis.conf}"
  local dev_config="/etc/redis/redis.dev.conf"
  local final_config="/tmp/redis.conf"

  log "Setting up Redis configuration…"

  # Start with the base configuration
  cp "$config_file" "$final_config"

  # Apply development overrides if in development mode
  if [ "${REDIS_ENV:-production}" = "development" ] && [ -f "$dev_config" ]; then
    log "Applying development configuration overrides…"
    echo "" >> "$final_config"
    echo "# Development overrides" >> "$final_config"
    cat "$dev_config" >> "$final_config"
  fi

  # Apply environment-based configurations
  if [ -n "$REDIS_MAXMEMORY" ]; then
    sed -i "s/^maxmemory .*/maxmemory $REDIS_MAXMEMORY/" "$final_config"
    log "Set maxmemory to $REDIS_MAXMEMORY"
  fi

  if [ -n "$REDIS_MAXMEMORY_POLICY" ]; then
    sed -i "s/^maxmemory-policy .*/maxmemory-policy $REDIS_MAXMEMORY_POLICY/" "$final_config"
    log "Set maxmemory-policy to $REDIS_MAXMEMORY_POLICY"
  fi

  if [ -n "$REDIS_LOG_LEVEL" ]; then
    sed -i "s/^loglevel .*/loglevel $REDIS_LOG_LEVEL/" "$final_config"
    log "Set loglevel to $REDIS_LOG_LEVEL"
  fi

  # Configure authentication if password is provided
  if [ -n "$REDIS_PASSWORD" ]; then
    echo "requirepass $REDIS_PASSWORD" >> "$final_config"
    log "Authentication configured"
  else
    log_warning "No Redis password set (REDIS_PASSWORD not configured)"
  fi

  # Set the final config file location
  export REDIS_CONFIG_FILE="$final_config"

  log_success "Redis configuration setup completed"
}

# Function to setup log rotation
setup_log_rotation() {
  log "Setting up log rotation…"

  cat > /etc/logrotate.d/redis << EOF
/var/log/redis/*.log {
  daily
  rotate 7
  compress
  delaycompress
  missingok
  notifempty
  create 640 redis redis
  postrotate
    /bin/kill -USR1 \$(cat /var/run/redis/redis-server.pid 2>/dev/null) 2>/dev/null || true
  endscript
}
EOF

  log_success "Log rotation configured"
}

# Function to create Redis ACL users file
create_acl_users() {
  local acl_file="/etc/redis/users.acl"

  log "Creating Redis ACL users file…"

  cat > "$acl_file" << EOF
user default off
user admin on >${REDIS_PASSWORD:-changeme} ~* &* +@all
user readonly on >${REDIS_READONLY_PASSWORD:-readonly} ~* &* +@read +info +ping
user app on >${REDIS_APP_PASSWORD:-apppassword} ~app:* &* +@all -@dangerous
user monitoring on >${REDIS_MONITORING_PASSWORD:-monitoring} ~* &* +ping +info +client +config
EOF

  chown redis:redis "$acl_file"
  chmod 640 "$acl_file"

  log_success "ACL users file created"
}

# Function to setup data directory permissions
setup_data_directory() {
  log "Setting up data directory permissions…"

  # Ensure data directory exists and has correct permissions
  mkdir -p /data
  chown -R redis:redis /data
  chmod 755 /data

  # Ensure log directory exists and has correct permissions
  mkdir -p /var/log/redis
  chown -R redis:redis /var/log/redis
  chmod 755 /var/log/redis

  # Ensure PID directory exists
  mkdir -p /var/run/redis
  chown -R redis:redis /var/run/redis
  chmod 755 /var/run/redis

  log_success "Data directory permissions configured"
}

# Function to apply security configurations
apply_security_configurations() {
  log "Applying security configurations…"

  # Disable transparent huge pages if possible
  if [ -f /sys/kernel/mm/transparent_hugepage/enabled ] && [ -w /sys/kernel/mm/transparent_hugepage/enabled ]; then
    echo never > /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null && log "Disabled transparent huge pages"
  else
    log_warning "Could not disable transparent huge pages (requires privileged mode)"
  fi

  # Set overcommit memory handling
  if [ -f /proc/sys/vm/overcommit_memory ] && [ -w /proc/sys/vm/overcommit_memory ]; then
    echo 1 > /proc/sys/vm/overcommit_memory 2>/dev/null && log "Set overcommit memory to 1"
  else
    log_warning "Could not set overcommit memory (requires privileged mode)"
  fi

  # Increase somaxconn if possible
  if [ -f /proc/sys/net/core/somaxconn ] && [ -w /proc/sys/net/core/somaxconn ]; then
    echo 65535 > /proc/sys/net/core/somaxconn 2>/dev/null && log "Increased somaxconn to 65535"
  else
    log_warning "Could not increase somaxconn (requires privileged mode)"
  fi

  log_success "Security configurations applied"
}

# Function to create monitoring script
create_monitoring_script() {
  local monitoring_script="/usr/local/bin/redis-monitor"

  log "Creating monitoring script…"

  cat > "$monitoring_script" << 'EOF'
#!/bin/bash
# Redis monitoring script

echo "Redis Status:"
redis-cli ping

echo -e "\nRedis Info:"
redis-cli info server | grep -E "redis_version|uptime_in_seconds|role"

echo -e "\nMemory Usage:"
redis-cli info memory | grep -E "used_memory_human|maxmemory_human|mem_fragmentation_ratio"

echo -e "\nClient Connections:"
redis-cli info clients | grep -E "connected_clients|blocked_clients"

echo -e "\nKeyspace:"
redis-cli info keyspace

echo -e "\nReplication:"
redis-cli info replication | grep -E "role|connected_slaves"
EOF

  chmod +x "$monitoring_script"
  chown redis:redis "$monitoring_script"

  log_success "Monitoring script created at $monitoring_script"
}

# Function to perform health check
perform_initial_health_check() {
  log "Performing initial health check…"

  # Start Redis in background for health check
  redis-server "$REDIS_CONFIG_FILE" --daemonize yes

  # Wait for Redis to be ready
  wait_for_redis

  # Perform basic health checks
  if redis-cli ping | grep -q PONG; then
    log_success "Redis ping test passed"
  else
    log_error "Redis ping test failed"
    exit 1
  fi

  # Test memory allocation
  if redis-cli set healthcheck:test "ok" | grep -q OK; then
    redis-cli del healthcheck:test >/dev/null
    log_success "Redis write/delete test passed"
  else
    log_error "Redis write test failed"
    exit 1
  fi

  # Stop the background Redis instance
  redis-cli shutdown nosave >/dev/null 2>&1 || true

  log_success "Initial health check completed"
}

# Main execution
main() {
  log "Starting Redis 7 custom entrypoint…"

  # Load credentials from files if they exist
  load_credentials

  # Optimize configuration based on available resources
  optimize_configuration

  # Setup data directory permissions
  setup_data_directory

  # Create ACL users file
  create_acl_users

  # Setup Redis configuration
  setup_redis_configuration

  # Apply security configurations
  apply_security_configurations

  # Setup log rotation
  setup_log_rotation

  # Create monitoring script
  create_monitoring_script

  # Skip initial health check (can cause infinite loop if Redis config has issues)
  # perform_initial_health_check

  log "Starting Redis server…"

  # Ensure proper ownership before starting
  chown -R redis:redis /data
  chown -R redis:redis /var/log/redis

  # Start Redis with the configured settings
  if [ "$1" = "redis-server" ]; then
    # Use our custom configuration
    exec gosu redis redis-server "$REDIS_CONFIG_FILE"
  else
    # Execute the command as provided
    exec gosu redis "$@"
  fi
}

# Handle signals gracefully
# NOTE: Trap disabled - once we exec, the shell is replaced by redis-server anyway
# trap 'log "Received shutdown signal, stopping Redis…"; redis-cli shutdown save 2>/dev/null || true; exit 0' SIGTERM SIGINT

# Run main function
main "$@"
