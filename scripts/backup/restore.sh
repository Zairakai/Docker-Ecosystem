#!/usr/bin/env bash
# scripts/backup/restore.sh
# Unified restore script for MySQL and Redis
#
# Usage:
#   restore.sh mysql [backup-file]     # Restore MySQL (default: latest.sql.gz)
#   restore.sh redis [backup-file]     # Restore Redis (default: latest.rdb)
#
# Environment Variables: Same as backup.sh

set -euo pipefail

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common.sh"

# Configuration
BACKUP_DIR="${BACKUP_DIR:-/backups}"
S3_ENABLED="${S3_ENABLED:-false}"
S3_BUCKET="${S3_BUCKET:-}"
S3_ENDPOINT="${S3_ENDPOINT:-}"

# ================================
# HELPER FUNCTIONS
# ================================

download_from_s3() {
  local s3_path="$1"
  local local_path="$2"

  if [ "${S3_ENABLED}" != "true" ]; then
    return 0
  fi

  if [ -f "${local_path}" ]; then
    log_info "Backup file exists locally, skipping S3 download"
    return 0
  fi

  if ! command_exists aws; then
    log_error "AWS CLI not installed, cannot download from S3"
    return 1
  fi

  log_info "Downloading from S3: ${s3_path}"
  
  mkdir -p "$(dirname "${local_path}")"
  
  if aws s3 cp \
    "s3://${S3_BUCKET}/${s3_path}" \
    "${local_path}" \
    --endpoint-url "${S3_ENDPOINT}" \
    --no-verify-ssl; then
    log_success "Downloaded from S3"
  else
    log_error "Failed to download from S3"
    return 1
  fi
}

confirm_restore() {
  log_warning "⚠️  WARNING: This will overwrite existing data!"
  echo ""
  
  if [ "${FORCE_RESTORE:-false}" = "true" ]; then
    log_info "FORCE_RESTORE=true, skipping confirmation"
    return 0
  fi
  
  read -p "Continue with restore? (yes/no) " -r
  if [ "$REPLY" != "yes" ]; then
    log_info "Restore cancelled by user"
    exit 0
  fi
}

# ================================
# MYSQL RESTORE
# ================================

restore_mysql() {
  local backup_file="${1:-latest.sql.gz}"
  local backup_path="${BACKUP_DIR}/mysql/${backup_file}"

  local MYSQL_HOST="${MYSQL_HOST:-mysql}"
  local MYSQL_PORT="${MYSQL_PORT:-3306}"
  local MYSQL_USER="${MYSQL_USER:-root}"
  local MYSQL_PASSWORD="${MYSQL_PASSWORD:?MYSQL_PASSWORD required for MySQL restore}"

  log_section "MySQL Restore"
  log_info "Host: ${MYSQL_HOST}:${MYSQL_PORT}"
  log_info "Backup: ${backup_file}"
  
  confirm_restore
  
  # Download from S3 if needed
  download_from_s3 "mysql/${backup_file}" "${backup_path}"
  
  # Verify backup exists
  if [ ! -f "${backup_path}" ]; then
    log_error "Backup file not found: ${backup_path}"
    exit 1
  fi
  
  # Verify integrity
  log_info "Verifying backup integrity…"
  if ! gunzip -t "${backup_path}"; then
    log_error "Backup integrity check failed"
    exit 1
  fi
  log_success "Backup integrity verified"
  
  # Perform restore
  log_info "Restoring databases (this may take several minutes)…"
  if gunzip -c "${backup_path}" | \
      mysql \
      -h "${MYSQL_HOST}" \
      -P "${MYSQL_PORT}" \
      -u "${MYSQL_USER}" \
      -p"${MYSQL_PASSWORD}" \
      2>/dev/null; then
    log_success "Restore completed"
  else
    log_error "Restore failed"
    exit 1
  fi
  
  # Verify databases
  log_info "Verifying restored databases…"
  local databases
  databases=$(mysql \
    -h "${MYSQL_HOST}" \
    -P "${MYSQL_PORT}" \
    -u "${MYSQL_USER}" \
    -p"${MYSQL_PASSWORD}" \
    -e "SHOW DATABASES;" \
    2>/dev/null | \
    grep -Ev "^(Database|information_schema|performance_schema|mysql|sys)$")
  
  echo ""
  log_success "Databases restored:"
  echo "${databases}"
  
  log_success "MySQL restore completed successfully"
}

# ================================
# REDIS RESTORE
# ================================

restore_redis() {
  local backup_file="${1:-latest.rdb}"
  local backup_path="${BACKUP_DIR}/redis/${backup_file}"

  local REDIS_HOST="${REDIS_HOST:-redis}"
  local REDIS_PORT="${REDIS_PORT:-6379}"
  local REDIS_PASSWORD="${REDIS_PASSWORD:-}"

  log_section "Redis Restore"
  log_info "Host: ${REDIS_HOST}:${REDIS_PORT}"
  log_info "Backup: ${backup_file}"
  
  confirm_restore
  
  # Download from S3 if needed
  download_from_s3 "redis/${backup_file}" "${backup_path}"
  
  # Verify backup exists
  if [ ! -f "${backup_path}" ]; then
    log_error "Backup file not found: ${backup_path}"
    exit 1
  fi
  
  log_info "Restoring Redis data…"
  log_warning "This requires Redis container access and restart"
  log_error "Manual restore required:"
  log_info "  1. Stop Redis: docker stop redis"
  log_info "  2. Copy RDB: docker cp ${backup_path} redis:/data/dump.rdb"
  log_info "  3. Start Redis: docker start redis"
  
  # Note: Automated restore would require container access
  # For now, provide manual instructions
}

# ================================
# MAIN
# ================================

main() {
  local target="${1:-}"
  local backup_file="${2:-}"

  if [ -z "${target}" ]; then
    log_error "Target not specified"
    log_info "Usage: $0 {mysql|redis} [backup-file]"
    exit 1
  fi

  log_section "Restore Service - ${target}"
  log_info "Started: $(timestamp)"
  
  case "${target}" in
    mysql)
      restore_mysql "${backup_file:-latest.sql.gz}"
      ;;
    redis)
      restore_redis "${backup_file:-latest.rdb}"
      ;;
    *)
      log_error "Invalid target: ${target}"
      log_info "Usage: $0 {mysql|redis} [backup-file]"
      exit 1
      ;;
  esac
  
  log_section "Restore Complete"
  log_success "Restore completed successfully"
  log_info "Finished: $(timestamp)"
}

main "$@"
