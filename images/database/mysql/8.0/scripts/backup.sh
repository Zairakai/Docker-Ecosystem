#!/bin/bash
set -eo pipefail

# MySQL 8.4 Backup Script
# Comprehensive backup solution with multiple strategies

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default configuration
BACKUP_DIR=${BACKUP_DIR:-"/backups"}
BACKUP_RETENTION_DAYS=${BACKUP_RETENTION_DAYS:-7}
MYSQL_HOST=${MYSQL_HOST:-"localhost"}
MYSQL_PORT=${MYSQL_PORT:-3306}
MYSQL_USER=${MYSQL_USER:-"root"}
MYSQL_PASSWORD=${MYSQL_PASSWORD:-""}
MYSQL_DATABASE=${MYSQL_DATABASE:-""}
BACKUP_TYPE=${BACKUP_TYPE:-"logical"}  # logical, physical, or binlog
COMPRESSION=${COMPRESSION:-"gzip"}   # gzip, xz, or none
PARALLEL_THREADS=${PARALLEL_THREADS:-4}

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
  echo "  -t, --type TYPE       Backup type: logical, physical, binlog (default: logical)"
  echo "  -d, --database DB     Specific database to backup (default: all databases)"
  echo "  -c, --compression TYPE  Compression: gzip, xz, none (default: gzip)"
  echo "  -p, --parallel THREADS  Number of parallel threads (default: 4)"
  echo "  -r, --retention DAYS    Retention period in days (default: 7)"
  echo "  -o, --output DIR      Output directory (default: /backups)"
  echo "  -h, --help         Show this help message"
  echo ""
  echo "Environment variables:"
  echo "  MYSQL_HOST         MySQL host (default: localhost)"
  echo "  MYSQL_PORT         MySQL port (default: 3306)"
  echo "  MYSQL_USER         MySQL user (default: root)"
  echo "  MYSQL_PASSWORD       MySQL password"
  echo "  MYSQL_ROOT_PASSWORD    Alternative to MYSQL_PASSWORD"
}

# Function to parse command line arguments
parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      -t| -type)
        BACKUP_TYPE="$2"
        shift 2
        ;;
      -d| -database)
        MYSQL_DATABASE="$2"
        shift 2
        ;;
      -c| -compression)
        COMPRESSION="$2"
        shift 2
        ;;
      -p| -parallel)
        PARALLEL_THREADS="$2"
        shift 2
        ;;
      -r| -retention)
        BACKUP_RETENTION_DAYS="$2"
        shift 2
        ;;
      -o| -output)
        BACKUP_DIR="$2"
        shift 2
        ;;
      -h| -help)
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

  # Set password from environment if not set
  if [ -z "$MYSQL_PASSWORD" ] && [ -n "$MYSQL_ROOT_PASSWORD" ]; then
    MYSQL_PASSWORD="$MYSQL_ROOT_PASSWORD"
  fi

  # Test MySQL connectivity
  if ! mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "SELECT 1;" &>/dev/null; then
    log_error "Cannot connect to MySQL server"
    exit 1
  fi

  # Check required tools based on backup type
  case $BACKUP_TYPE in
    logical)
      if ! command -v mysqldump &> /dev/null; then
        log_error "mysqldump is not available"
        exit 1
      fi
      ;;
    physical)
      if ! command -v xtrabackup &> /dev/null; then
        log_error "xtrabackup is not available for physical backups"
        log_warning "Falling back to logical backup"
        BACKUP_TYPE="logical"
      fi
      ;;
    binlog)
      if ! command -v mysqlbinlog &> /dev/null; then
        log_error "mysqlbinlog is not available"
        exit 1
      fi
      ;;
  esac

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

# Function to get database list
get_database_list() {
  if [ -n "$MYSQL_DATABASE" ]; then
    echo "$MYSQL_DATABASE"
  else
    mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" \
      -e "SHOW DATABASES;" --skip-column-names | \
      grep -v -E '^(information_schema|performance_schema|mysql|sys)$'
  fi
}

# Function to create logical backup using mysqldump
create_logical_backup() {
  local timestamp
  timestamp=$(date +%Y%m%d_%H%M%S)
  local backup_file
  local compression_ext=""
  local compression_cmd=""

  log "Starting logical backup…"

  # Set compression
  case $COMPRESSION in
    gzip)
      compression_ext=".gz"
      compression_cmd="gzip"
      ;;
    xz)
      compression_ext=".xz"
      compression_cmd="xz"
      ;;
    none)
      compression_ext=""
      ;;
  esac

  if [ -n "$MYSQL_DATABASE" ]; then
    # Single database backup
    backup_file="$BACKUP_DIR/mysql_${MYSQL_DATABASE}_${timestamp}.sql${compression_ext}"
    log "Backing up database: $MYSQL_DATABASE"

    mysqldump \
      -h "$MYSQL_HOST" \
      -P "$MYSQL_PORT" \
      -u "$MYSQL_USER" \
      -p"$MYSQL_PASSWORD" \
      --single-transaction \
      --routines \
      --triggers \
      --events \
      --add-drop-database \
      --create-options \
      --disable-keys \
      --extended-insert \
      --quick \
      --lock-tables=false \
      --set-gtid-purged=OFF \
      --databases "$MYSQL_DATABASE" | $compression_cmd > "$backup_file"

  else
    # All databases backup
    backup_file="$BACKUP_DIR/mysql_all_databases_${timestamp}.sql${compression_ext}"
    log "Backing up all databases"

    mysqldump \
      -h "$MYSQL_HOST" \
      -P "$MYSQL_PORT" \
      -u "$MYSQL_USER" \
      -p"$MYSQL_PASSWORD" \
      --single-transaction \
      --routines \
      --triggers \
      --events \
      --add-drop-database \
      --create-options \
      --disable-keys \
      --extended-insert \
      --quick \
      --lock-tables=false \
      --set-gtid-purged=OFF \
      --all-databases | $compression_cmd > "$backup_file"
  fi

  # Verify backup file
  if [ -f "$backup_file" ] && [ -s "$backup_file" ]; then
    local backup_size
    backup_size=$(du -h "$backup_file" | cut -f1)
    log_success "Logical backup completed: $backup_file ($backup_size)"
    echo "$backup_file"
  else
    log_error "Logical backup failed or resulted in empty file"
    exit 1
  fi
}

# Function to create physical backup using xtrabackup
create_physical_backup() {
  local timestamp
  timestamp=$(date +%Y%m%d_%H%M%S)
  local backup_dir="$BACKUP_DIR/mysql_physical_${timestamp}"
  local backup_archive
  local compression_ext=""

  log "Starting physical backup…"

  # Set compression extension
  case $COMPRESSION in
    gzip)
      compression_ext=".tar.gz"
      ;;
    xz)
      compression_ext=".tar.xz"
      ;;
    none)
      compression_ext=".tar"
      ;;
  esac

  backup_archive="$BACKUP_DIR/mysql_physical_${timestamp}${compression_ext}"

  # Create physical backup
  mkdir -p "$backup_dir"

  xtrabackup \
    --backup \
    --host="$MYSQL_HOST" \
    --port="$MYSQL_PORT" \
    --user="$MYSQL_USER" \
    --password="$MYSQL_PASSWORD" \
    --parallel="$PARALLEL_THREADS" \
    --target-dir="$backup_dir" \
    --compress \
    --compress-threads="$PARALLEL_THREADS"

  if [ $? -eq 0 ]; then
    log "Physical backup completed, preparing backup…"

    # Prepare the backup
    xtrabackup \
      --prepare \
      --target-dir="$backup_dir" \
      --decompress \
      --remove-original

    if [ $? -eq 0 ]; then
      log "Backup preparation completed, creating archive…"

      # Create compressed archive
      case $COMPRESSION in
        gzip)
          tar -czf "$backup_archive" -C "$BACKUP_DIR" "$(basename "$backup_dir")"
          ;;
        xz)
          tar -cJf "$backup_archive" -C "$BACKUP_DIR" "$(basename "$backup_dir")"
          ;;
        none)
          tar -cf "$backup_archive" -C "$BACKUP_DIR" "$(basename "$backup_dir")"
          ;;
      esac

      # Remove temporary directory
      rm -rf "$backup_dir"

      if [ -f "$backup_archive" ] && [ -s "$backup_archive" ]; then
        local backup_size
        backup_size=$(du -h "$backup_archive" | cut -f1)
        log_success "Physical backup completed: $backup_archive ($backup_size)"
        echo "$backup_archive"
      else
        log_error "Failed to create backup archive"
        exit 1
      fi
    else
      log_error "Backup preparation failed"
      exit 1
    fi
  else
    log_error "Physical backup failed"
    exit 1
  fi
}

# Function to backup binary logs
create_binlog_backup() {
  local timestamp
  timestamp=$(date +%Y%m%d_%H%M%S)
  local binlog_dir="$BACKUP_DIR/mysql_binlog_${timestamp}"
  local backup_archive
  local compression_ext=""

  log "Starting binary log backup…"

  # Set compression extension
  case $COMPRESSION in
    gzip)
      compression_ext=".tar.gz"
      ;;
    xz)
      compression_ext=".tar.xz"
      ;;
    none)
      compression_ext=".tar"
      ;;
  esac

  backup_archive="$BACKUP_DIR/mysql_binlog_${timestamp}${compression_ext}"

  # Create binlog directory
  mkdir -p "$binlog_dir"

  # Get list of binary logs
  local binlog_files
  binlog_files=$(mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" \
    -e "SHOW BINARY LOGS;" --skip-column-names | awk '{print $1}')

  if [ -n "$binlog_files" ]; then
    log "Found binary logs, copying…"

    # Copy binary logs
    for binlog in $binlog_files; do
      log "Copying binary log: $binlog"
      mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" \
        -e "FLUSH BINARY LOGS;"

      # Note: This is a simplified approach. In production, you might want to use
      # a more sophisticated method to ensure consistency
      cp "/var/lib/mysql/$binlog" "$binlog_dir/" 2>/dev/null || \
        log_warning "Could not copy $binlog (file may not be accessible)"
    done

    # Create master info
    mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" \
      -e "SHOW MASTER STATUS\G" > "$binlog_dir/master_status.info"

    # Create compressed archive
    case $COMPRESSION in
      gzip)
        tar -czf "$backup_archive" -C "$BACKUP_DIR" "$(basename "$binlog_dir")"
        ;;
      xz)
        tar -cJf "$backup_archive" -C "$BACKUP_DIR" "$(basename "$binlog_dir")"
        ;;
      none)
        tar -cf "$backup_archive" -C "$BACKUP_DIR" "$(basename "$binlog_dir")"
        ;;
    esac

    # Remove temporary directory
    rm -rf "$binlog_dir"

    if [ -f "$backup_archive" ] && [ -s "$backup_archive" ]; then
      local backup_size
      backup_size=$(du -h "$backup_archive" | cut -f1)
      log_success "Binary log backup completed: $backup_archive ($backup_size)"
      echo "$backup_archive"
    else
      log_error "Failed to create binlog backup archive"
      exit 1
    fi
  else
    log_warning "No binary logs found"
    return 0
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
  done < <(find "$BACKUP_DIR" -name "mysql_*" -type f -mtime +$BACKUP_RETENTION_DAYS -print0)

  if [ $deleted_count -gt 0 ]; then
    log_success "Deleted $deleted_count old backup(s)"
  else
    log "No old backups to delete"
  fi
}

# Function to generate backup report
generate_backup_report() {
  local backup_file="$1"
  local backup_type="$2"
  local start_time="$3"
  local end_time="$4"

  if [ -n "$backup_file" ] && [ -f "$backup_file" ]; then
    local backup_size
    backup_size=$(du -h "$backup_file" | cut -f1)
    local duration
    duration=$((end_time - start_time))

    log "=== BACKUP REPORT ==="
    log "Type: $backup_type"
    log "File: $backup_file"
    log "Size: $backup_size"
    log "Duration: ${duration}s"
    log "Timestamp: $(date)"
    log "===================="

    # Create report file
    local report_file
    report_file="$BACKUP_DIR/backup_report_$(date +%Y%m%d_%H%M%S).txt"
    cat > "$report_file" << EOF
MySQL Backup Report
==================

Backup Type: $backup_type
Backup File: $backup_file
Backup Size: $backup_size
Duration: ${duration} seconds
Database: ${MYSQL_DATABASE:-"All databases"}
Host: $MYSQL_HOST:$MYSQL_PORT
User: $MYSQL_USER
Compression: $COMPRESSION
Timestamp: $(date)
Status: SUCCESS

EOF
    log "Backup report saved: $report_file"
  fi
}

# Main execution function
main() {
  local start_time
  start_time=$(date +%s)
  local backup_file=""

  log "Starting MySQL backup process…"
  log "Backup type: $BACKUP_TYPE"
  log "Compression: $COMPRESSION"
  log "Output directory: $BACKUP_DIR"

  # Parse command line arguments
  parse_arguments "$@"

  # Validate prerequisites
  validate_prerequisites

  # Create backup based on type
  case $BACKUP_TYPE in
    logical)
      backup_file=$(create_logical_backup)
      ;;
    physical)
      backup_file=$(create_physical_backup)
      ;;
    binlog)
      backup_file=$(create_binlog_backup)
      ;;
    *)
      log_error "Invalid backup type: $BACKUP_TYPE"
      show_usage
      exit 1
      ;;
  esac

  # Clean up old backups
  cleanup_old_backups

  # Generate backup report
  local end_time
  end_time=$(date +%s)
  generate_backup_report "$backup_file" "$BACKUP_TYPE" "$start_time" "$end_time"

  log_success "Backup process completed successfully"
}

# Handle signals
trap 'log_error "Backup interrupted"; exit 1' SIGTERM SIGINT

# Run main function
main "$@"
