#!/bin/bash
set -eo pipefail

# Redis 7 Restore Script
# Comprehensive restore solution for RDB and AOF backups

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default configuration
BACKUP_FILE=""
REDIS_HOST=${REDIS_HOST:-"localhost"}
REDIS_PORT=${REDIS_PORT:-6379}
REDIS_PASSWORD=${REDIS_PASSWORD:-""}
RESTORE_TYPE=""  # Will be auto-detected
FORCE_RESTORE=${FORCE_RESTORE:-false}
FLUSH_BEFORE_RESTORE=${FLUSH_BEFORE_RESTORE:-false}

# Logging function
log() {
  echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] [RESTORE]${NC} $1"
}

log_error() {
  echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] [RESTORE] ERROR:${NC} $1" >&2
}

log_warning() {
  echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] [RESTORE] WARNING:${NC} $1"
}

log_success() {
  echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] [RESTORE] SUCCESS:${NC} $1"
}

# Function to show usage
show_usage() {
  echo "Usage: $0 [OPTIONS] BACKUP_FILE"
  echo ""
  echo "Options:"
  echo "  -t, --type TYPE      Restore type: rdb, aof, memory (auto-detected if not specified)"
  echo "  -f, --force       Force restore (don't prompt for confirmation)"
  echo "  -F, --flush       Flush all databases before restore"
  echo "  -h, --help        Show this help message"
  echo ""
  echo "Environment variables:"
  echo "  REDIS_HOST        Redis host (default: localhost)"
  echo "  REDIS_PORT        Redis port (default: 6379)"
  echo "  REDIS_PASSWORD      Redis password"
  echo ""
  echo "Examples:"
  echo "  $0 /backups/redis_rdb_20240101_120000.rdb.gz"
  echo "  $0 -f /backups/redis_aof_20240101_120000.aof.gz"
  echo "  $0 -F /backups/redis_memory_20240101_120000.json.gz"
}

# Function to parse command line arguments
parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      -t| -type)
        RESTORE_TYPE="$2"
        shift 2
        ;;
      -f| -force)
        FORCE_RESTORE=true
        shift
        ;;
      -F| -flush)
        FLUSH_BEFORE_RESTORE=true
        shift
        ;;
      -h| -help)
        show_usage
        exit 0
        ;;
      -*)
        log_error "Unknown option: $1"
        show_usage
        exit 1
        ;;
      *)
        if [ -z "$BACKUP_FILE" ]; then
          BACKUP_FILE="$1"
        else
          log_error "Multiple backup files specified"
          show_usage
          exit 1
        fi
        shift
        ;;
    esac
  done

  if [ -z "$BACKUP_FILE" ]; then
    log_error "Backup file not specified"
    show_usage
    exit 1
  fi
}

# Function to detect restore type
detect_restore_type() {
  local filename
  filename=$(basename "$BACKUP_FILE")

  if [ -n "$RESTORE_TYPE" ]; then
    log "Using specified restore type: $RESTORE_TYPE"
    return 0
  fi

  log "Detecting restore type from filename: $filename"

  if [[ $filename == *"rdb"* ]]; then
    RESTORE_TYPE="rdb"
  elif [[ $filename == *"aof"* ]]; then
    RESTORE_TYPE="aof"
  elif [[ $filename == *"memory"* ]] || [[ $filename == *".json"* ]]; then
    RESTORE_TYPE="memory"
  else
    log_error "Cannot detect restore type from filename. Please specify with -t option."
    exit 1
  fi

  log "Detected restore type: $RESTORE_TYPE"
}

# Function to validate prerequisites
validate_prerequisites() {
  log "Validating prerequisites…"

  # Check if backup file exists
  if [ ! -f "$BACKUP_FILE" ]; then
    log_error "Backup file does not exist: $BACKUP_FILE"
    exit 1
  fi

  # Set Redis authentication
  if [ -n "$REDIS_PASSWORD" ]; then
    export REDISCLI_AUTH="$REDIS_PASSWORD"
  fi

  # Test Redis connectivity
  if ! redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" ping >/dev/null 2>&1; then
    log_error "Cannot connect to Redis server at $REDIS_HOST:$REDIS_PORT"
    exit 1
  fi

  # Check required tools
  if ! command -v redis-cli &> /dev/null; then
    log_error "redis-cli is not available"
    exit 1
  fi

  # Check decompression tools
  if [[ $BACKUP_FILE == *.gz ]]; then
    if ! command -v gunzip &> /dev/null; then
      log_error "gunzip is not available"
      exit 1
    fi
  elif [[ $BACKUP_FILE == *.xz ]]; then
    if ! command -v xz &> /dev/null; then
      log_error "xz is not available"
      exit 1
    fi
  fi

  log_success "Prerequisites validated"
}

# Function to get Redis data directory
get_redis_data_dir() {
  local data_dir
  if data_dir=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" config get dir 2>/dev/null | tail -1); then
    echo "$data_dir"
  else
    echo "/data"  # Default fallback
  fi
}

# Function to create pre-restore backup
create_pre_restore_backup() {
  if [ "$FORCE_RESTORE" = "false" ]; then
    log "Creating pre-restore backup…"

    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_dir="/tmp"
    local backup_file="$backup_dir/pre_restore_backup_${timestamp}.rdb"

    # Force RDB save
    if redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" bgsave >/dev/null 2>&1; then
      # Wait for save to complete
      local save_completed=false
      local timeout=60
      local count=0

      while [ "$save_completed" = "false" ] && [ $count -lt $timeout ]; do
        local info
        info=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" info persistence 2>/dev/null)
        local rdb_bgsave_in_progress
        rdb_bgsave_in_progress=$(echo "$info" | grep "rdb_bgsave_in_progress:" | cut -d: -f2 | tr -d '\r')

        if [ "$rdb_bgsave_in_progress" = "0" ]; then
          save_completed=true
        fi

        sleep 1
        count=$((count + 1))
      done

      if [ "$save_completed" = "true" ]; then
        local data_dir
        data_dir=$(get_redis_data_dir)
        local rdb_filename
        rdb_filename=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" config get dbfilename 2>/dev/null | tail -1)
        local rdb_path="$data_dir/$rdb_filename"

        if [ -f "$rdb_path" ]; then
          cp "$rdb_path" "$backup_file"
          log_success "Pre-restore backup created: $backup_file"
          echo "PRE_RESTORE_BACKUP=$backup_file"
        else
          log_warning "Could not find RDB file for pre-restore backup"
        fi
      else
        log_warning "Pre-restore backup timed out"
      fi
    else
      log_warning "Failed to create pre-restore backup"
    fi
  fi
}

# Function to flush Redis databases
flush_redis_databases() {
  if [ "$FLUSH_BEFORE_RESTORE" = "true" ]; then
    log_warning "Flushing all Redis databases…"

    if redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" flushall >/dev/null 2>&1; then
      log_success "All databases flushed"
    else
      log_error "Failed to flush databases"
      exit 1
    fi
  fi
}

# Function to restore RDB backup
restore_rdb_backup() {
  log "Starting RDB backup restore…"

  # Get Redis configuration
  local data_dir
  data_dir=$(get_redis_data_dir)
  local rdb_filename
  rdb_filename=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" config get dbfilename 2>/dev/null | tail -1)
  local rdb_path="$data_dir/$rdb_filename"

  log "Redis data directory: $data_dir"
  log "RDB filename: $rdb_filename"
  log "RDB path: $rdb_path"

  # Create temporary file for decompression
  local temp_file="/tmp/restore_rdb_$$"

  # Decompress backup file
  log "Decompressing backup file…"
  if [[ $BACKUP_FILE == *.gz ]]; then
    gunzip -c "$BACKUP_FILE" > "$temp_file"
  elif [[ $BACKUP_FILE == *.xz ]]; then
    xz -dc "$BACKUP_FILE" > "$temp_file"
  else
    cp "$BACKUP_FILE" "$temp_file"
  fi

  if [ ! -f "$temp_file" ] || [ ! -s "$temp_file" ]; then
    log_error "Failed to decompress backup file or file is empty"
    exit 1
  fi

  # Stop Redis to replace RDB file
  log "Stopping Redis for RDB replacement…"
  if redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" shutdown save >/dev/null 2>&1; then
    log "Redis stopped gracefully"

    # Wait for Redis to stop
    sleep 2

    # Replace RDB file
    log "Replacing RDB file…"
    if [ -f "$rdb_path" ]; then
      cp "$rdb_path" "${rdb_path}.backup.$(date +%s)" 2>/dev/null || true
    fi

    cp "$temp_file" "$rdb_path"
    chown redis:redis "$rdb_path" 2>/dev/null || true

    # Start Redis again
    log "Starting Redis…"
    # Note: This assumes Redis will be restarted by the container orchestrator
    # In a manual setup, you would need to start Redis explicitly

    # Wait for Redis to be available again
    local timeout=30
    local count=0
    while ! redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" ping >/dev/null 2>&1; do
      if [ $count -ge $timeout ]; then
        log_error "Redis failed to start within $timeout seconds"
        exit 1
      fi
      count=$((count + 1))
      sleep 1
    done

    log_success "Redis started successfully"
  else
    log_error "Failed to stop Redis server"
    exit 1
  fi

  # Clean up temporary file
  rm -f "$temp_file"

  log_success "RDB backup restore completed"
}

# Function to restore AOF backup
restore_aof_backup() {
  log "Starting AOF backup restore…"

  # Check if AOF is enabled
  local aof_enabled
  aof_enabled=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" config get appendonly 2>/dev/null | tail -1)
  if [ "$aof_enabled" != "yes" ]; then
    log "Enabling AOF for restore…"
    redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" config set appendonly yes >/dev/null 2>&1
  fi

  # Get Redis configuration
  local data_dir
  data_dir=$(get_redis_data_dir)
  local aof_filename
  aof_filename=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" config get appendfilename 2>/dev/null | tail -1)
  local aof_path="$data_dir/$aof_filename"

  log "AOF filename: $aof_filename"
  log "AOF path: $aof_path"

  # Create temporary file for decompression
  local temp_file="/tmp/restore_aof_$$"

  # Decompress backup file
  log "Decompressing backup file…"
  if [[ $BACKUP_FILE == *.gz ]]; then
    gunzip -c "$BACKUP_FILE" > "$temp_file"
  elif [[ $BACKUP_FILE == *.xz ]]; then
    xz -dc "$BACKUP_FILE" > "$temp_file"
  else
    cp "$BACKUP_FILE" "$temp_file"
  fi

  if [ ! -f "$temp_file" ] || [ ! -s "$temp_file" ]; then
    log_error "Failed to decompress backup file or file is empty"
    exit 1
  fi

  # Stop Redis to replace AOF file
  log "Stopping Redis for AOF replacement…"
  if redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" shutdown save >/dev/null 2>&1; then
    log "Redis stopped gracefully"

    # Wait for Redis to stop
    sleep 2

    # Replace AOF file
    log "Replacing AOF file…"
    if [ -f "$aof_path" ]; then
      cp "$aof_path" "${aof_path}.backup.$(date +%s)" 2>/dev/null || true
    fi

    cp "$temp_file" "$aof_path"
    chown redis:redis "$aof_path" 2>/dev/null || true

    # Start Redis again
    log "Starting Redis…"

    # Wait for Redis to be available again
    local timeout=30
    local count=0
    while ! redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" ping >/dev/null 2>&1; do
      if [ $count -ge $timeout ]; then
        log_error "Redis failed to start within $timeout seconds"
        exit 1
      fi
      count=$((count + 1))
      sleep 1
    done

    log_success "Redis started successfully"
  else
    log_error "Failed to stop Redis server"
    exit 1
  fi

  # Clean up temporary file
  rm -f "$temp_file"

  log_success "AOF backup restore completed"
}

# Function to restore memory dump
restore_memory_dump() {
  log "Starting memory dump restore…"

  # Create temporary file for decompression
  local temp_file="/tmp/restore_memory_$$"

  # Decompress backup file
  log "Decompressing backup file…"
  if [[ $BACKUP_FILE == *.gz ]]; then
    gunzip -c "$BACKUP_FILE" > "$temp_file"
  elif [[ $BACKUP_FILE == *.xz ]]; then
    xz -dc "$BACKUP_FILE" > "$temp_file"
  else
    cp "$BACKUP_FILE" "$temp_file"
  fi

  if [ ! -f "$temp_file" ] || [ ! -s "$temp_file" ]; then
    log_error "Failed to decompress backup file or file is empty"
    exit 1
  fi

  # Validate JSON format
  if ! jq empty "$temp_file" 2>/dev/null; then
    log_error "Backup file is not valid JSON"
    rm -f "$temp_file"
    exit 1
  fi

  # Extract databases from JSON
  log "Parsing memory dump…"
  local databases
  databases=$(jq -r '.redis_backup.databases[] | @base64' "$temp_file" 2>/dev/null)

  if [ -z "$databases" ]; then
    log_error "No databases found in memory dump"
    rm -f "$temp_file"
    exit 1
  fi

  # Restore each database
  echo "$databases" | while IFS= read -r encoded_db; do
    local db_data
    db_data=$(echo "$encoded_db" | base64 --decode)
    local db_num
    db_num=$(echo "$db_data" | jq -r '.database')
    local keys
    keys=$(echo "$db_data" | jq -r '.keys[] | @base64')

    log "Restoring database $db_num…"

    # Restore each key
    echo "$keys" | while IFS= read -r encoded_key; do
      local key_data
      key_data=$(echo "$encoded_key" | base64 --decode)
      local key
      key=$(echo "$key_data" | jq -r '.key')
      local key_type
      key_type=$(echo "$key_data" | jq -r '.type')
      local ttl
      ttl=$(echo "$key_data" | jq -r '.ttl')

      case $key_type in
        string)
          local value
          value=$(echo "$key_data" | jq -r '.value')
          redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" -n "$db_num" set "$key" "$value" >/dev/null 2>&1
          ;;
        list)
          local list_items
          list_items=$(echo "$key_data" | jq -r '.value[]')
          echo "$list_items" | while IFS= read -r item; do
            redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" -n "$db_num" lpush "$key" "$item" >/dev/null 2>&1
          done
          ;;
        set)
          local set_items
          set_items=$(echo "$key_data" | jq -r '.value[]')
          echo "$set_items" | while IFS= read -r item; do
            redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" -n "$db_num" sadd "$key" "$item" >/dev/null 2>&1
          done
          ;;
        hash)
          local hash_fields
          hash_fields=$(echo "$key_data" | jq -r '.value | to_entries[] | "\(.key) \(.value)"')
          echo "$hash_fields" | while IFS= read -r field value; do
            redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" -n "$db_num" hset "$key" "$field" "$value" >/dev/null 2>&1
          done
          ;;
        zset)
          local zset_items
          zset_items=$(echo "$key_data" | jq -r '.value | @sh')
          # shellcheck disable=SC2034,SC2154
          local -a zset_array
          eval "zset_array=($zset_items)"
          for ((i=0; i<${#zset_array[@]}; i+=2)); do
            local member="${zset_array[i]}"
            local score="${zset_array[i+1]}"
            redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" -n "$db_num" zadd "$key" "$score" "$member" >/dev/null 2>&1
          done
          ;;
      esac

      # Set TTL if applicable
      if [ "$ttl" -gt 0 ]; then
        redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" -n "$db_num" expire "$key" "$ttl" >/dev/null 2>&1
      fi
    done

    log_success "Database $db_num restored"
  done

  # Clean up temporary file
  rm -f "$temp_file"

  log_success "Memory dump restore completed"
}

# Function to verify restore
verify_restore() {
  log "Verifying restore…"

  # Test basic connectivity
  if ! redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" ping >/dev/null 2>&1; then
    log_error "Redis is not accessible after restore"
    return 1
  fi

  # Check if data was restored
  local total_keys=0
  for db in {0..15}; do
    local db_size
    db_size=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" -n "$db" dbsize 2>/dev/null || echo "0")
    total_keys=$((total_keys + db_size))
  done

  log "Total keys after restore: $total_keys"

  if [ $total_keys -eq 0 ]; then
    log_warning "No keys found after restore - backup might have been empty"
  else
    log_success "Data verification completed - found $total_keys keys"
  fi

  # Check Redis server info
  local server_info
  server_info=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" info server 2>/dev/null)
  local redis_version
  redis_version=$(echo "$server_info" | grep "redis_version:" | cut -d: -f2 | tr -d '\r')
  log "Redis version: $redis_version"

  log_success "Restore verification completed"
  return 0
}

# Function to generate restore report
generate_restore_report() {
  local start_time="$1"
  local end_time="$2"
  local status="$3"

  local duration
  duration=$((end_time - start_time))
  local backup_size
  backup_size=$(du -h "$BACKUP_FILE" | cut -f1)

  log "=== RESTORE REPORT ==="
  log "Backup File: $BACKUP_FILE"
  log "Backup Size: $backup_size"
  log "Restore Type: $RESTORE_TYPE"
  log "Duration: ${duration}s"
  log "Status: $status"
  log "Timestamp: $(date)"
  log "====================="

  # Create report file
  local report_file
  report_file="/tmp/restore_report_$(date +%Y%m%d_%H%M%S).txt"
  cat > "$report_file" << EOF
Redis Restore Report
===================

Backup File: $BACKUP_FILE
Backup Size: $backup_size
Restore Type: $RESTORE_TYPE
Redis Host: $REDIS_HOST:$REDIS_PORT
Duration: ${duration} seconds
Force Restore: $FORCE_RESTORE
Flush Before Restore: $FLUSH_BEFORE_RESTORE
Status: $status
Timestamp: $(date)

EOF
  log "Restore report saved: $report_file"
}

# Main execution function
main() {
  local start_time
  start_time=$(date +%s)

  log "Starting Redis restore process…"

  # Parse command line arguments
  parse_arguments "$@"

  log "Backup file: $BACKUP_FILE"
  log "Force restore: $FORCE_RESTORE"
  log "Flush before restore: $FLUSH_BEFORE_RESTORE"

  # Detect restore type
  detect_restore_type

  # Validate prerequisites
  validate_prerequisites

  # Create pre-restore backup (unless force restore is enabled)
  create_pre_restore_backup

  # Flush databases if requested
  flush_redis_databases

  # Perform restore based on type
  case $RESTORE_TYPE in
    rdb)
      restore_rdb_backup
      ;;
    aof)
      restore_aof_backup
      ;;
    memory)
      restore_memory_dump
      ;;
    *)
      log_error "Invalid restore type: $RESTORE_TYPE"
      exit 1
      ;;
  esac

  # Verify restore
  if verify_restore; then
    local end_time
    end_time=$(date +%s)
    generate_restore_report "$start_time" "$end_time" "SUCCESS"
    log_success "Restore process completed successfully"
  else
    local end_time
    end_time=$(date +%s)
    generate_restore_report "$start_time" "$end_time" "FAILED"
    log_error "Restore verification failed"
    exit 1
  fi
}

# Handle signals
trap 'log_error "Restore interrupted"; exit 1' SIGTERM SIGINT

# Run main function
main "$@"
