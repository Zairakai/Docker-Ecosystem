#!/bin/bash
set -eo pipefail

# MySQL 8.4 Restore Script
# Comprehensive restore solution for different backup types

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default configuration
BACKUP_FILE=""
MYSQL_HOST=${MYSQL_HOST:-"localhost"}
MYSQL_PORT=${MYSQL_PORT:-3306}
MYSQL_USER=${MYSQL_USER:-"root"}
MYSQL_PASSWORD=${MYSQL_PASSWORD:-""}
MYSQL_DATABASE=${MYSQL_DATABASE:-""}
RESTORE_TYPE=""  # Will be auto-detected
FORCE_RESTORE=${FORCE_RESTORE:-false}
RESTORE_POINT=""  # For point-in-time recovery

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
  echo "  -d, --database DB     Target database name (for single database restores)"
  echo "  -t, --type TYPE       Restore type: logical, physical, binlog (auto-detected if not specified)"
  echo "  -f, --force        Force restore (drops existing databases/tables)"
  echo "  -p, --point-in-time TIME Point-in-time recovery (YYYY-MM-DD HH:MM:SS)"
  echo "  -h, --help         Show this help message"
  echo ""
  echo "Environment variables:"
  echo "  MYSQL_HOST         MySQL host (default: localhost)"
  echo "  MYSQL_PORT         MySQL port (default: 3306)"
  echo "  MYSQL_USER         MySQL user (default: root)"
  echo "  MYSQL_PASSWORD       MySQL password"
  echo "  MYSQL_ROOT_PASSWORD    Alternative to MYSQL_PASSWORD"
  echo ""
  echo "Examples:"
  echo "  $0 /backups/mysql_all_databases_20240101_120000.sql.gz"
  echo "  $0 -d myapp /backups/mysql_myapp_20240101_120000.sql.gz"
  echo "  $0 -f /backups/mysql_physical_20240101_120000.tar.xz"
  echo "  $0 -p \"2024-01-01 12:00:00\" /backups/mysql_binlog_20240101_120000.tar.gz"
}

# Function to parse command line arguments
parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      -d|--database)
        MYSQL_DATABASE="$2"
        shift 2
        ;;
      -t|--type)
        RESTORE_TYPE="$2"
        shift 2
        ;;
      -f|--force)
        FORCE_RESTORE=true
        shift
        ;;
      -p|--point-in-time)
        RESTORE_POINT="$2"
        shift 2
        ;;
      -h|--help)
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

# Function to detect backup type
detect_backup_type() {
  local filename
  filename=$(basename "$BACKUP_FILE")

  if [ -n "$RESTORE_TYPE" ]; then
    log "Using specified restore type: $RESTORE_TYPE"
    return 0
  fi

  log "Detecting backup type from filename: $filename"

  if [[ $filename == *"physical"* ]]; then
    RESTORE_TYPE="physical"
  elif [[ $filename == *"binlog"* ]]; then
    RESTORE_TYPE="binlog"
  elif [[ $filename == *".sql"* ]]; then
    RESTORE_TYPE="logical"
  else
    log_error "Cannot detect backup type from filename. Please specify with -t option."
    exit 1
  fi

  log "Detected backup type: $RESTORE_TYPE"
}

# Function to validate prerequisites
validate_prerequisites() {
  log "Validating prerequisites…"

  # Check if backup file exists
  if [ ! -f "$BACKUP_FILE" ]; then
    log_error "Backup file does not exist: $BACKUP_FILE"
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

  # Check required tools based on restore type
  case $RESTORE_TYPE in
    logical)
      if ! command -v mysql &> /dev/null; then
        log_error "mysql client is not available"
        exit 1
      fi
      ;;
    physical)
      if ! command -v xtrabackup &> /dev/null; then
        log_error "xtrabackup is not available for physical restores"
        exit 1
      fi
      ;;
    binlog)
      if ! command -v mysqlbinlog &> /dev/null; then
        log_error "mysqlbinlog is not available"
        exit 1
      fi
      ;;
  esac

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

# Function to create database backup before restore
create_pre_restore_backup() {
  if [ "$FORCE_RESTORE" = "false" ]; then
    log "Creating pre-restore backup…"

    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_dir="/tmp"
    local backup_file="$backup_dir/pre_restore_backup_${timestamp}.sql.gz"

    if [ -n "$MYSQL_DATABASE" ]; then
      # Backup specific database
      mysqldump \
        -h "$MYSQL_HOST" \
        -P "$MYSQL_PORT" \
        -u "$MYSQL_USER" \
        -p"$MYSQL_PASSWORD" \
        --single-transaction \
        --routines \
        --triggers \
        --events \
        --databases "$MYSQL_DATABASE" | gzip > "$backup_file"
    else
      # Backup all databases
      mysqldump \
        -h "$MYSQL_HOST" \
        -P "$MYSQL_PORT" \
        -u "$MYSQL_USER" \
        -p"$MYSQL_PASSWORD" \
        --single-transaction \
        --routines \
        --triggers \
        --events \
        --all-databases | gzip > "$backup_file"
    fi

    if [ -f "$backup_file" ] && [ -s "$backup_file" ]; then
      log_success "Pre-restore backup created: $backup_file"
      echo "PRE_RESTORE_BACKUP=$backup_file"
    else
      log_warning "Failed to create pre-restore backup"
    fi
  fi
}

# Function to restore logical backup
restore_logical_backup() {
  log "Starting logical backup restore…"

  local decompression_cmd="cat"

  # Determine decompression method
  if [[ $BACKUP_FILE == *.gz ]]; then
    decompression_cmd="gunzip -c"
  elif [[ $BACKUP_FILE == *.xz ]]; then
    decompression_cmd="xz -dc"
  fi

  # Prepare restore command
  local mysql_cmd="mysql -h $MYSQL_HOST -P $MYSQL_PORT -u $MYSQL_USER -p$MYSQL_PASSWORD"

  # Add database parameter if specified
  if [ -n "$MYSQL_DATABASE" ]; then
    mysql_cmd="$mysql_cmd $MYSQL_DATABASE"
  fi

  # Check if we need to drop existing databases/tables
  if [ "$FORCE_RESTORE" = "true" ]; then
    log_warning "Force restore enabled - existing data will be dropped"

    if [ -n "$MYSQL_DATABASE" ]; then
      log "Dropping database: $MYSQL_DATABASE"
      mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" \
        -e "DROP DATABASE IF EXISTS \`$MYSQL_DATABASE\`;"
    else
      log_warning "Force restore with all databases - this will drop all existing databases"
      # Note: In production, you might want to be more selective here
    fi
  fi

  # Restore the backup
  log "Restoring backup file: $BACKUP_FILE"

  if $decompression_cmd "$BACKUP_FILE" | $mysql_cmd; then
    log_success "Logical backup restore completed successfully"
  else
    log_error "Logical backup restore failed"
    exit 1
  fi
}

# Function to restore physical backup
restore_physical_backup() {
  log "Starting physical backup restore…"

  local temp_dir="/tmp/mysql_restore_$$"
  local mysql_datadir="/var/lib/mysql"

  # Create temporary directory
  mkdir -p "$temp_dir"

  # Extract backup
  log "Extracting backup archive…"
  if [[ $BACKUP_FILE == *.tar.gz ]]; then
    tar -xzf "$BACKUP_FILE" -C "$temp_dir"
  elif [[ $BACKUP_FILE == *.tar.xz ]]; then
    tar -xJf "$BACKUP_FILE" -C "$temp_dir"
  elif [[ $BACKUP_FILE == *.tar ]]; then
    tar -xf "$BACKUP_FILE" -C "$temp_dir"
  else
    log_error "Unsupported archive format for physical backup"
    exit 1
  fi

  # Find the extracted directory
  local backup_dir
  backup_dir=$(find "$temp_dir" -type d -name "mysql_physical_*" | head -1)
  if [ -z "$backup_dir" ]; then
    log_error "Could not find extracted backup directory"
    exit 1
  fi

  log "Found backup directory: $backup_dir"

  # Stop MySQL service (this assumes MySQL is running as a service)
  log "Stopping MySQL service…"
  if command -v systemctl &> /dev/null; then
    systemctl stop mysql || log_warning "Could not stop MySQL service"
  else
    mysqladmin -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" shutdown || log_warning "Could not shutdown MySQL"
  fi

  # Backup current data directory if force restore is not enabled
  if [ "$FORCE_RESTORE" = "false" ] && [ -d "$mysql_datadir" ]; then
    local backup_current_dir
    backup_current_dir="${mysql_datadir}_backup_$(date +%Y%m%d_%H%M%S)"
    log "Backing up current data directory to: $backup_current_dir"
    mv "$mysql_datadir" "$backup_current_dir"
  else
    log "Removing current data directory…"
    rm -rf "$mysql_datadir"
  fi

  # Restore the backup
  log "Restoring data directory…"
  mv "$backup_dir" "$mysql_datadir"

  # Set proper ownership
  chown -R mysql:mysql "$mysql_datadir"

  # Prepare the backup (if it's an xtrabackup)
  if [ -f "$mysql_datadir/xtrabackup_checkpoints" ]; then
    log "Preparing xtrabackup…"
    xtrabackup --prepare --target-dir="$mysql_datadir"
  fi

  # Start MySQL service
  log "Starting MySQL service…"
  if command -v systemctl &> /dev/null; then
    systemctl start mysql
  else
    mysqld --user=mysql --daemonize
  fi

  # Wait for MySQL to be ready
  local timeout=60
  local count=0
  while ! mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "SELECT 1;" &>/dev/null; do
    if [ $count -ge $timeout ]; then
      log_error "MySQL failed to start within $timeout seconds"
      exit 1
    fi
    count=$((count + 1))
    sleep 1
  done

  # Clean up
  rm -rf "$temp_dir"

  log_success "Physical backup restore completed successfully"
}

# Function to restore binary log backup
restore_binlog_backup() {
  log "Starting binary log restore…"

  if [ -z "$RESTORE_POINT" ]; then
    log_error "Point-in-time recovery requires --point-in-time option"
    exit 1
  fi

  local temp_dir="/tmp/mysql_binlog_restore_$$"

  # Create temporary directory
  mkdir -p "$temp_dir"

  # Extract backup
  log "Extracting binlog archive…"
  if [[ $BACKUP_FILE == *.tar.gz ]]; then
    tar -xzf "$BACKUP_FILE" -C "$temp_dir"
  elif [[ $BACKUP_FILE == *.tar.xz ]]; then
    tar -xJf "$BACKUP_FILE" -C "$temp_dir"
  elif [[ $BACKUP_FILE == *.tar ]]; then
    tar -xf "$BACKUP_FILE" -C "$temp_dir"
  else
    log_error "Unsupported archive format for binlog backup"
    exit 1
  fi

  # Find the extracted directory
  local binlog_dir
  binlog_dir=$(find "$temp_dir" -type d -name "mysql_binlog_*" | head -1)
  if [ -z "$binlog_dir" ]; then
    log_error "Could not find extracted binlog directory"
    exit 1
  fi

  log "Found binlog directory: $binlog_dir"

  # Apply binary logs up to the restore point
  log "Applying binary logs up to: $RESTORE_POINT"

  for binlog_file in "$binlog_dir"/mysql-bin.*; do
    if [ -f "$binlog_file" ]; then
      log "Processing binlog: $(basename "$binlog_file")"

      mysqlbinlog \
        --stop-datetime="$RESTORE_POINT" \
        "$binlog_file" | \
        mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD"
    fi
  done

  # Clean up
  rm -rf "$temp_dir"

  log_success "Binary log restore completed successfully"
}

# Function to verify restore
verify_restore() {
  log "Verifying restore…"

  # Test basic connectivity
  if ! mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "SELECT 1;" &>/dev/null; then
    log_error "MySQL is not accessible after restore"
    return 1
  fi

  # Check if specified database exists (if applicable)
  if [ -n "$MYSQL_DATABASE" ]; then
    local db_exists
    db_exists=$(mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" \
      -e "SHOW DATABASES LIKE '$MYSQL_DATABASE';" --skip-column-names | wc -l)

    if [ "$db_exists" -eq 0 ]; then
      log_error "Database '$MYSQL_DATABASE' does not exist after restore"
      return 1
    else
      log_success "Database '$MYSQL_DATABASE' verified"
    fi
  fi

  # Check for any obvious issues
  local error_count
  error_count=$(mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" \
    -e "SELECT COUNT(*) FROM INFORMATION_SCHEMA.SCHEMA_PRIVILEGES;" --skip-column-names 2>/dev/null || echo "0")

  log "Schema privileges count: $error_count"

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
  log "Target Database: ${MYSQL_DATABASE:-"All databases"}"
  log "Duration: ${duration}s"
  log "Status: $status"
  log "Timestamp: $(date)"
  log "====================="

  # Create report file
  local report_file
  report_file="/tmp/restore_report_$(date +%Y%m%d_%H%M%S).txt"
  cat > "$report_file" << EOF
MySQL Restore Report
===================

Backup File: $BACKUP_FILE
Backup Size: $backup_size
Restore Type: $RESTORE_TYPE
Target Database: ${MYSQL_DATABASE:-"All databases"}
Target Host: $MYSQL_HOST:$MYSQL_PORT
Duration: ${duration} seconds
Force Restore: $FORCE_RESTORE
Point-in-Time: ${RESTORE_POINT:-"N/A"}
Status: $status
Timestamp: $(date)

EOF
  log "Restore report saved: $report_file"
}

# Main execution function
main() {
  local start_time
  start_time=$(date +%s)

  log "Starting MySQL restore process…"

  # Parse command line arguments
  parse_arguments "$@"

  log "Backup file: $BACKUP_FILE"
  log "Target database: ${MYSQL_DATABASE:-"All databases"}"
  log "Force restore: $FORCE_RESTORE"

  # Detect backup type
  detect_backup_type

  # Validate prerequisites
  validate_prerequisites

  # Create pre-restore backup (unless force restore is enabled)
  create_pre_restore_backup

  # Perform restore based on type
  case $RESTORE_TYPE in
    logical)
      restore_logical_backup
      ;;
    physical)
      restore_physical_backup
      ;;
    binlog)
      restore_binlog_backup
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
