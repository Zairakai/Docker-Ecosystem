#!/bin/bash
set -eo pipefail

# Redis 7 Backup Script
# Comprehensive backup solution with RDB and AOF support

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default configuration
BACKUP_DIR=${BACKUP_DIR:-"/backups"}
BACKUP_RETENTION_DAYS=${BACKUP_RETENTION_DAYS:-7}
REDIS_HOST=${REDIS_HOST:-"localhost"}
REDIS_PORT=${REDIS_PORT:-6379}
REDIS_PASSWORD=${REDIS_PASSWORD:-""}
BACKUP_TYPE=${BACKUP_TYPE:-"rdb"}  # rdb, aof, or both
COMPRESSION=${COMPRESSION:-"gzip"}  # gzip, xz, or none

# Logging function
log() {
  echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] [BACKUP]${NC} $1"
}

log_error() {
  echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] [BACKUP] ERROR:${NC} $1" >&2
}

log_warning() {
  echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] [BACKUP] WARNING:${NC} $1"
}

log_success() {
  echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] [BACKUP] SUCCESS:${NC} $1"
}

# Function to show usage
show_usage() {
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  -t, --type TYPE       Backup type: rdb, aof, both (default: rdb)"
  echo "  -c, --compression TYPE  Compression: gzip, xz, none (default: gzip)"
  echo "  -r, --retention DAYS    Retention period in days (default: 7)"
  echo "  -o, --output DIR      Output directory (default: /backups)"
  echo "  -h, --help         Show this help message"
  echo ""
  echo "Environment variables:"
  echo "  REDIS_HOST         Redis host (default: localhost)"
  echo "  REDIS_PORT         Redis port (default: 6379)"
  echo "  REDIS_PASSWORD       Redis password"
}

# Function to parse command line arguments
parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      -t|--type)
        BACKUP_TYPE="$2"
        shift 2
        ;;
      -c|--compression)
        COMPRESSION="$2"
        shift 2
        ;;
      -r|--retention)
        BACKUP_RETENTION_DAYS="$2"
        shift 2
        ;;
      -o|--output)
        BACKUP_DIR="$2"
        shift 2
        ;;
      -h|--help)
        show_usage
        exit 0
        ;;
      *)
        log_error "Unknown option: $1"
        show_usage
        exit 1
        ;;
    esac
  done
}

# Function to validate prerequisites
validate_prerequisites() {
  log "Validating prerequisites…"

  # Check if backup directory exists and is writable
  if [ ! -d "$BACKUP_DIR" ]; then
    log "Creating backup directory: $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"
  fi

  if [ ! -w "$BACKUP_DIR" ]; then
    log_error "Backup directory is not writable: $BACKUP_DIR"
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

  # Check compression tools
  case $COMPRESSION in
    gzip)
      if ! command -v gzip &> /dev/null; then
        log_error "gzip is not available"
        exit 1
      fi
      ;;
    xz)
      if ! command -v xz &> /dev/null; then
        log_error "xz is not available"
        exit 1
      fi
      ;;
  esac

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

# Function to create RDB backup
create_rdb_backup() {
  local timestamp
  timestamp=$(date +%Y%m%d_%H%M%S)
  local backup_file
  local compression_ext=""
  local compression_cmd=""

  log "Starting RDB backup…"

  # Set compression
  case $COMPRESSION in
    gzip)
      compression_ext=".gz"
      # shellcheck disable=SC2034
      compression_cmd="gzip"  # Used for documentation
      ;;
    xz)
      compression_ext=".xz"
      # shellcheck disable=SC2034
      compression_cmd="xz"  # Used for documentation
      ;;
    none)
      compression_ext=""
      ;;
  esac

  backup_file="$BACKUP_DIR/redis_rdb_${timestamp}.rdb${compression_ext}"

  # Get Redis data directory
  local data_dir
  data_dir=$(get_redis_data_dir)
  local rdb_filename
  rdb_filename=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" config get dbfilename 2>/dev/null | tail -1)
  local rdb_path="$data_dir/$rdb_filename"

  log "Redis data directory: $data_dir"
  log "RDB filename: $rdb_filename"

  # Force RDB save
  log "Triggering RDB save…"
  if redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" bgsave >/dev/null 2>&1; then
    log "Background save initiated"

    # Wait for background save to complete
    local save_in_progress=1
    local timeout=300  # 5 minutes timeout
    local count=0

    while [ $save_in_progress -eq 1 ] && [ $count -lt $timeout ]; do
      local lastsave_time
      lastsave_time=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" lastsave 2>/dev/null)
      sleep 1
      local current_lastsave
      current_lastsave=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" lastsave 2>/dev/null)

      if [ "$current_lastsave" -gt "$lastsave_time" ]; then
        save_in_progress=0
        log "Background save completed"
      fi

      count=$((count + 1))
    done

    if [ $save_in_progress -eq 1 ]; then
      log_error "Background save timed out"
      exit 1
    fi
  else
    log_error "Failed to initiate background save"
    exit 1
  fi

  # Copy and compress RDB file
  if [ -f "$rdb_path" ]; then
    log "Copying RDB file: $rdb_path"

    case $COMPRESSION in
      gzip)
        gzip -c "$rdb_path" > "$backup_file"
        ;;
      xz)
        xz -c "$rdb_path" > "$backup_file"
        ;;
      none)
        cp "$rdb_path" "$backup_file"
        ;;
    esac

    if [ -f "$backup_file" ] && [ -s "$backup_file" ]; then
      local backup_size
      backup_size=$(du -h "$backup_file" | cut -f1)
      log_success "RDB backup completed: $backup_file ($backup_size)"
      echo "$backup_file"
    else
      log_error "RDB backup failed or resulted in empty file"
      exit 1
    fi
  else
    log_error "RDB file not found: $rdb_path"
    exit 1
  fi
}

# Function to create AOF backup
create_aof_backup() {
  local timestamp
  timestamp=$(date +%Y%m%d_%H%M%S)
  local backup_file
  local compression_ext=""

  log "Starting AOF backup…"

  # Set compression extension
  case $COMPRESSION in
    gzip)
      compression_ext=".gz"
      ;;
    xz)
      compression_ext=".xz"
      ;;
    none)
      compression_ext=""
      ;;
  esac

  backup_file="$BACKUP_DIR/redis_aof_${timestamp}.aof${compression_ext}"

  # Check if AOF is enabled
  local aof_enabled
  aof_enabled=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" config get appendonly 2>/dev/null | tail -1)
  if [ "$aof_enabled" != "yes" ]; then
    log_warning "AOF is not enabled on Redis server"
    return 0
  fi

  # Get Redis data directory and AOF filename
  local data_dir
  data_dir=$(get_redis_data_dir)
  local aof_filename
  aof_filename=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" config get appendfilename 2>/dev/null | tail -1)
  local aof_path="$data_dir/$aof_filename"

  log "AOF filename: $aof_filename"

  # Force AOF rewrite for consistency
  log "Triggering AOF rewrite…"
  if redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" bgrewriteaof >/dev/null 2>&1; then
    log "Background AOF rewrite initiated"

    # Wait for AOF rewrite to complete
    local rewrite_in_progress=1
    local timeout=300  # 5 minutes timeout
    local count=0

    while [ $rewrite_in_progress -eq 1 ] && [ $count -lt $timeout ]; do
      local aof_rewrite_status
      aof_rewrite_status=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" info persistence 2>/dev/null | grep "aof_rewrite_in_progress:" | cut -d: -f2 | tr -d '\r')

      if [ "$aof_rewrite_status" = "0" ]; then
        rewrite_in_progress=0
        log "AOF rewrite completed"
      fi

      sleep 1
      count=$((count + 1))
    done

    if [ $rewrite_in_progress -eq 1 ]; then
      log_error "AOF rewrite timed out"
      exit 1
    fi
  else
    log_warning "Failed to initiate AOF rewrite, proceeding with current AOF file"
  fi

  # Copy and compress AOF file
  if [ -f "$aof_path" ]; then
    log "Copying AOF file: $aof_path"

    case $COMPRESSION in
      gzip)
        gzip -c "$aof_path" > "$backup_file"
        ;;
      xz)
        xz -c "$aof_path" > "$backup_file"
        ;;
      none)
        cp "$aof_path" "$backup_file"
        ;;
    esac

    if [ -f "$backup_file" ] && [ -s "$backup_file" ]; then
      local backup_size
      backup_size=$(du -h "$backup_file" | cut -f1)
      log_success "AOF backup completed: $backup_file ($backup_size)"
      echo "$backup_file"
    else
      log_error "AOF backup failed or resulted in empty file"
      exit 1
    fi
  else
    log_error "AOF file not found: $aof_path"
    exit 1
  fi
}

# Function to create memory dump backup
create_memory_dump() {
  local timestamp
  timestamp=$(date +%Y%m%d_%H%M%S)
  local backup_file="$BACKUP_DIR/redis_memory_${timestamp}.json"
  local compression_ext=""

  log "Starting memory dump backup…"

  # Set compression extension
  case $COMPRESSION in
    gzip)
      compression_ext=".gz"
      ;;
    xz)
      compression_ext=".xz"
      ;;
    none)
      compression_ext=""
      ;;
  esac

  local final_backup_file="${backup_file}${compression_ext}"

  # Create JSON dump of all keys
  log "Creating JSON dump of Redis data…"

  {
    echo "{"
    echo "  \"redis_backup\": {"
    echo "  \"timestamp\": \"$(date -Iseconds)\","
    echo "  \"server_info\": $(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" info server | grep -E "(redis_version|uptime_in_seconds)" | sed 's/:/": "/' | sed 's/^/  "/' | sed 's/$/",/' | sed '$s/,$//'),"
    echo "  \"databases\": ["

    # Get list of databases with keys
    local db_count=0
    for db in {0..15}; do
      local key_count
      key_count=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" -n "$db" dbsize 2>/dev/null)
      if [ "$key_count" -gt 0 ]; then
        if [ $db_count -gt 0 ]; then
          echo ","
        fi

        echo "    {"
        echo "    \"database\": $db,"
        echo "    \"key_count\": $key_count,"
        echo "    \"keys\": ["

        # Dump all keys from this database
        local key_index=0
        redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" -n "$db" --scan | while IFS= read -r key; do
          if [ $key_index -gt 0 ]; then
            echo ","
          fi

          local key_type
          key_type=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" -n "$db" type "$key" 2>/dev/null)
          local key_ttl
          key_ttl=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" -n "$db" ttl "$key" 2>/dev/null)

          echo -n "      {"
          echo -n "\"key\": \"$key\", \"type\": \"$key_type\", \"ttl\": $key_ttl"

          case $key_type in
            string)
              local value
              value=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" -n "$db" get "$key" 2>/dev/null | sed 's/"/\\"/g')
              echo -n ", \"value\": \"$value\""
              ;;
            list)
              local list_data
              list_data=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" -n "$db" lrange "$key" 0 -1 2>/dev/null | jq -R . | jq -s .)
              echo -n ", \"value\": $list_data"
              ;;
            set)
              local set_data
              set_data=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" -n "$db" smembers "$key" 2>/dev/null | jq -R . | jq -s .)
              echo -n ", \"value\": $set_data"
              ;;
            hash)
              local hash_data
              hash_data=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" -n "$db" hgetall "$key" 2>/dev/null | jq -R . | jq -s . | jq 'reduce .[] as $item ({}; . + {($item): .[$item]})')
              echo -n ", \"value\": $hash_data"
              ;;
            zset)
              local zset_data
              zset_data=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" -n "$db" zrange "$key" 0 -1 withscores 2>/dev/null | jq -R . | jq -s .)
              echo -n ", \"value\": $zset_data"
              ;;
          esac

          echo -n "}"
          key_index=$((key_index + 1))
        done

        echo ""
        echo "    ]"
        echo -n "    }"
        db_count=$((db_count + 1))
      fi
    done

    echo ""
    echo "  ]"
    echo "  }"
    echo "}"
  } > "$backup_file"

  # Compress the backup if needed
  case $COMPRESSION in
    gzip)
      gzip "$backup_file"
      ;;
    xz)
      xz "$backup_file"
      ;;
    none)
      mv "$backup_file" "$final_backup_file"
      ;;
  esac

  if [ -f "$final_backup_file" ] && [ -s "$final_backup_file" ]; then
    local backup_size
    backup_size=$(du -h "$final_backup_file" | cut -f1)
    log_success "Memory dump backup completed: $final_backup_file ($backup_size)"
    echo "$final_backup_file"
  else
    log_error "Memory dump backup failed"
    exit 1
  fi
}

# Function to clean old backups
cleanup_old_backups() {
  log "Cleaning up backups older than $BACKUP_RETENTION_DAYS days…"

  local deleted_count=0

  # Find and delete old backup files
  while IFS= read -r -d '' file; do
    log "Deleting old backup: $(basename "$file")"
    rm -f "$file"
    ((deleted_count++))
  done < <(find "$BACKUP_DIR" -name "redis_*" -type f -mtime +$BACKUP_RETENTION_DAYS -print0)

  if [ $deleted_count -gt 0 ]; then
    log_success "Deleted $deleted_count old backup(s)"
  else
    log "No old backups to delete"
  fi
}

# Function to create backup manifest
create_backup_manifest() {
  local backup_files=("$@")
  local manifest_file
  manifest_file="$BACKUP_DIR/backup_manifest_$(date +%Y%m%d_%H%M%S).json"

  log "Creating backup manifest…"

  {
    echo "{"
    echo "  \"backup_info\": {"
    echo "  \"timestamp\": \"$(date -Iseconds)\","
    echo "  \"type\": \"$BACKUP_TYPE\","
    echo "  \"compression\": \"$COMPRESSION\","
    echo "  \"redis_host\": \"$REDIS_HOST:$REDIS_PORT\","
    echo "  \"redis_version\": \"$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" info server | grep "redis_version:" | cut -d: -f2 | tr -d '\r')\","
    echo "  \"files\": ["

    local file_count=0
    for backup_file in "${backup_files[@]}"; do
      if [ -f "$backup_file" ]; then
        if [ $file_count -gt 0 ]; then
          echo ","
        fi

        local file_size
        file_size=$(stat -c%s "$backup_file")
        local file_md5
        file_md5=$(md5sum "$backup_file" | cut -d' ' -f1)

        echo "    {"
        echo "    \"filename\": \"$(basename "$backup_file")\","
        echo "    \"path\": \"$backup_file\","
        echo "    \"size_bytes\": $file_size,"
        echo "    \"size_human\": \"$(du -h "$backup_file" | cut -f1)\","
        echo "    \"md5_checksum\": \"$file_md5\""
        echo -n "    }"

        file_count=$((file_count + 1))
      fi
    done

    echo ""
    echo "  ]"
    echo "  }"
    echo "}"
  } > "$manifest_file"

  log "Backup manifest created: $manifest_file"
}

# Function to generate backup report
generate_backup_report() {
  local backup_files=("$@")
  local start_time="$1"
  local end_time="$2"

  if [ ${#backup_files[@]} -gt 0 ]; then
    local total_size=0
    local duration
    duration=$((end_time - start_time))

    for backup_file in "${backup_files[@]}"; do
      if [ -f "$backup_file" ]; then
        local file_size
        file_size=$(stat -c%s "$backup_file")
        total_size=$((total_size + file_size))
      fi
    done

    local total_size_human
    total_size_human=$(numfmt --to=iec-i --suffix=B $total_size)

    log "=== BACKUP REPORT ==="
    log "Type: $BACKUP_TYPE"
    log "Files: ${#backup_files[@]}"
    log "Total Size: $total_size_human"
    log "Duration: ${duration}s"
    log "Timestamp: $(date)"
    log "===================="

    # Create report file
    local report_file
    report_file="$BACKUP_DIR/backup_report_$(date +%Y%m%d_%H%M%S).txt"
    cat > "$report_file" << EOF
Redis Backup Report
==================

Backup Type: $BACKUP_TYPE
Number of Files: ${#backup_files[@]}
Total Size: $total_size_human
Duration: ${duration} seconds
Redis Host: $REDIS_HOST:$REDIS_PORT
Compression: $COMPRESSION
Timestamp: $(date)
Status: SUCCESS

Files:
$(printf '%s\n' "${backup_files[@]}" | sed 's/^/  - /')

Redis Version: $(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" info server | grep "redis_version:" | cut -d: -f2 | tr -d '\r')
Database Count: $(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" info keyspace | grep -c "^db[0-9]" || echo "0")

EOF
    log "Backup report saved: $report_file"
  fi
}

# Main execution function
main() {
  local start_time
  start_time=$(date +%s)
  local backup_files=()

  log "Starting Redis backup process…"
  log "Backup type: $BACKUP_TYPE"
  log "Compression: $COMPRESSION"
  log "Output directory: $BACKUP_DIR"

  # Parse command line arguments
  parse_arguments "$@"

  # Validate prerequisites
  validate_prerequisites

  # Create backups based on type
  case $BACKUP_TYPE in
    rdb)
      # shellcheck disable=SC2207
      backup_files+=($(create_rdb_backup))
      ;;
    aof)
      # shellcheck disable=SC2207
      backup_files+=($(create_aof_backup))
      ;;
    both)
      # shellcheck disable=SC2207
      backup_files+=($(create_rdb_backup))
      # shellcheck disable=SC2207
      backup_files+=($(create_aof_backup))
      ;;
    memory)
      # shellcheck disable=SC2207
      backup_files+=($(create_memory_dump))
      ;;
    *)
      log_error "Invalid backup type: $BACKUP_TYPE"
      show_usage
      exit 1
      ;;
  esac

  # Create backup manifest
  create_backup_manifest "${backup_files[@]}"

  # Clean up old backups
  cleanup_old_backups

  # Generate backup report
  local end_time
  end_time=$(date +%s)
  generate_backup_report "${backup_files[@]}" "$start_time" "$end_time"

  log_success "Backup process completed successfully"
}

# Handle signals
trap 'log_error "Backup interrupted"; exit 1' SIGTERM SIGINT

# Run main function
main "$@"
