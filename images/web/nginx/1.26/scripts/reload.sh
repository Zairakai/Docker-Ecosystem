#!/bin/bash

# Nginx graceful reload script
# This script safely reloads nginx configuration without dropping connections

set -e

# Configuration
NGINX_PID_FILE="/var/run/nginx.pid"
BACKUP_DIR="/tmp/nginx-config-backup"
TIMEOUT="${RELOAD_TIMEOUT:-30}"

# Function to log messages
log() {
  echo "[RELOAD] $(date +'%Y-%m-%d %H:%M:%S') $1"
}

# Function to check if nginx is running
is_nginx_running() {
  if [[ -f "$NGINX_PID_FILE" ]]; then
    local pid
    pid=$(cat "$NGINX_PID_FILE")
    if kill -0 "$pid" 2>/dev/null; then
      return 0
    fi
  fi
  return 1
}

# Function to backup current configuration
backup_config() {
  log "Creating configuration backup…"

  # Create backup directory with timestamp
  local timestamp
  timestamp=$(date +%Y%m%d_%H%M%S)
  local backup_path="${BACKUP_DIR}/${timestamp}"

  mkdir -p "$backup_path"

  # Backup main configuration files
  cp -r /etc/nginx/nginx.conf "$backup_path/"
  cp -r /etc/nginx/conf.d/ "$backup_path/"

  # Store backup path for potential restore
  echo "$backup_path" > /tmp/nginx-last-backup

  log "Configuration backed up to: $backup_path"
}

# Function to validate new configuration
validate_config() {
  log "Validating nginx configuration…"

  if nginx -t; then
    log "Configuration validation successful"
    return 0
  else
    log "ERROR: Configuration validation failed"
    return 1
  fi
}

# Function to restore configuration from backup
restore_config() {
  local backup_file="/tmp/nginx-last-backup"

  if [[ -f "$backup_file" ]]; then
    local backup_path
    backup_path=$(cat "$backup_file")

    if [[ -d "$backup_path" ]]; then
      log "Restoring configuration from backup: $backup_path"

      # Restore main configuration
      cp "$backup_path/nginx.conf" /etc/nginx/

      # Restore conf.d directory
      rm -rf /etc/nginx/conf.d/
      cp -r "$backup_path/conf.d/" /etc/nginx/

      log "Configuration restored from backup"
      return 0
    fi
  fi

  log "ERROR: No backup found to restore"
  return 1
}

# Function to perform graceful reload
graceful_reload() {
  log "Starting graceful reload process…"

  if ! is_nginx_running; then
    log "ERROR: Nginx is not running, cannot reload"
    return 1
  fi

  # Create configuration backup
  backup_config

  # Validate configuration before reload
  if ! validate_config; then
    log "ERROR: Configuration validation failed, aborting reload"
    return 1
  fi

  # Get current nginx PID
  local nginx_pid
  nginx_pid=$(cat "$NGINX_PID_FILE")
  log "Sending reload signal to nginx (PID: $nginx_pid)"

  # Send reload signal
  if kill -HUP "$nginx_pid"; then
    log "Reload signal sent successfully"

    # Wait a moment and check if nginx is still running with same PID
    sleep 2

    if is_nginx_running && [[ $(cat "$NGINX_PID_FILE") == "$nginx_pid" ]]; then
      log "Graceful reload completed successfully"
      return 0
    else
      log "ERROR: Nginx PID changed or process died during reload"
      return 1
    fi
  else
    log "ERROR: Failed to send reload signal to nginx"
    return 1
  fi
}

# Function to test reload with rollback capability
test_reload() {
  log "Testing reload with automatic rollback on failure…"

  if graceful_reload; then
    log "Test reload successful"
    return 0
  else
    log "Test reload failed, attempting to restore configuration…"

    if restore_config; then
      log "Configuration restored, attempting recovery reload…"

      if graceful_reload; then
        log "Recovery reload successful"
        return 1  # Return 1 to indicate original reload failed
      else
        log "ERROR: Recovery reload also failed"
        return 2
      fi
    else
      log "ERROR: Failed to restore configuration"
      return 2
    fi
  fi
}

# Function to force reload (restart)
force_reload() {
  log "Performing force reload (restart)…"

  if is_nginx_running; then
    local nginx_pid
    nginx_pid=$(cat "$NGINX_PID_FILE")
    log "Stopping nginx (PID: $nginx_pid)"

    # Send TERM signal and wait for graceful shutdown
    kill -TERM "$nginx_pid"

    # Wait for process to stop
    local count=0
    while kill -0 "$nginx_pid" 2>/dev/null && [[ $count -lt $TIMEOUT ]]; do
      sleep 1
      count=$((count + 1))
    done

    if kill -0 "$nginx_pid" 2>/dev/null; then
      log "WARNING: Nginx did not stop gracefully, sending KILL signal"
      kill -KILL "$nginx_pid"
      sleep 2
    fi
  fi

  # Start nginx
  log "Starting nginx…"
  if nginx; then
    log "Force reload completed successfully"
    return 0
  else
    log "ERROR: Failed to start nginx"
    return 1
  fi
}

# Function to show reload status
show_status() {
  log "Nginx reload status information:"

  if is_nginx_running; then
    local pid
    pid=$(cat "$NGINX_PID_FILE")
    log "Nginx is running (PID: $pid)"

    # Show process information
    if command -v ps >/dev/null 2>&1; then
      log "Process details:"
      ps -p "$pid" -o pid,ppid,cmd,etime,pcpu,pmem
    fi

    # Show configuration test result
    log "Configuration status:"
    if nginx -t 2>&1 | sed 's/^/  /'; then
      log "Configuration is valid"
    else
      log "Configuration has errors"
    fi
  else
    log "Nginx is not running"
  fi

  # Show last backup information
  if [[ -f "/tmp/nginx-last-backup" ]]; then
    local backup_path
    backup_path=$(cat "/tmp/nginx-last-backup")
    log "Last configuration backup: $backup_path"
  fi
}

# Function to clean old backups
cleanup_backups() {
  local max_backups="${MAX_BACKUPS:-10}"

  if [[ -d "$BACKUP_DIR" ]]; then
    log "Cleaning up old configuration backups…"

    # Remove backups older than 7 days or keep only the latest N backups
    find "$BACKUP_DIR" -maxdepth 1 -type d -mtime +7 -exec rm -rf {} \; 2>/dev/null || true

    # Keep only the latest N backups
    local backup_count
    backup_count=$(find "$BACKUP_DIR" -maxdepth 1 -type d | wc -l)
    if [[ $backup_count -gt $max_backups ]]; then
      find "$BACKUP_DIR" -maxdepth 1 -type d -printf '%T@ %p\n' | sort -n | head -n -"$max_backups" | cut -d' ' -f2- | xargs rm -rf
    fi

    log "Backup cleanup completed"
  fi
}

# Main script logic
main() {
  case "${1:-reload}" in
    "reload"|"")
      graceful_reload
      ;;
    "test")
      test_reload
      ;;
    "force")
      force_reload
      ;;
    "status")
      show_status
      ;;
    "backup")
      backup_config
      ;;
    "restore")
      restore_config
      ;;
    "validate")
      validate_config
      ;;
    "cleanup")
      cleanup_backups
      ;;
    *)
      echo "Usage: $0 {reload|test|force|status|backup|restore|validate|cleanup}"
      echo ""
      echo "Commands:"
      echo "  reload   - Graceful reload (default)"
      echo "  test     - Test reload with automatic rollback on failure"
      echo "  force    - Force reload (restart nginx)"
      echo "  status   - Show nginx and reload status"
      echo "  backup   - Create configuration backup"
      echo "  restore  - Restore from last backup"
      echo "  validate - Validate current configuration"
      echo "  cleanup  - Clean up old backup files"
      echo ""
      echo "Environment variables:"
      echo "  RELOAD_TIMEOUT - Timeout for operations (default: 30s)"
      echo "  MAX_BACKUPS    - Maximum backups to keep (default: 10)"
      exit 1
      ;;
  esac
}

# Execute main function
main "$@"
