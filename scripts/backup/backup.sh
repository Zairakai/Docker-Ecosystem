#!/usr/bin/env bash
# scripts/backup/backup.sh
# Unified backup script for MySQL and Redis
#
# Usage:
#   backup.sh mysql      # Backup MySQL
#   backup.sh redis      # Backup Redis
#   backup.sh all        # Backup both
#
# Environment Variables:
#   BACKUP_DIR          - Base backup directory (default: /backups)
#   RETENTION_DAYS      - Number of days to keep backups (default: 7)
#   S3_ENABLED          - Enable S3/MinIO upload (true/false)
#   S3_BUCKET           - S3 bucket name
#   S3_ENDPOINT         - S3 endpoint URL
#   
#   # MySQL specific
#   MYSQL_HOST          - MySQL hostname (default: mysql)
#   MYSQL_PORT          - MySQL port (default: 3306)
#   MYSQL_USER          - MySQL username (default: root)
#   MYSQL_PASSWORD      - MySQL password (required)
#   
#   # Redis specific
#   REDIS_HOST          - Redis hostname (default: redis)
#   REDIS_PORT          - Redis port (default: 6379)
#   REDIS_PASSWORD      - Redis password (optional)

set -euo pipefail

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common.sh"

# Configuration
BACKUP_DIR="${BACKUP_DIR:-/backups}"
RETENTION_DAYS="${RETENTION_DAYS:-7}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# S3/MinIO configuration
S3_ENABLED="${S3_ENABLED:-false}"
S3_BUCKET="${S3_BUCKET:-}"
S3_ENDPOINT="${S3_ENDPOINT:-}"

# ================================
# HELPER FUNCTIONS
# ================================

upload_to_s3() {
  local file="$1"
  local s3_path="$2"

  if [ "${S3_ENABLED}" != "true" ]; then
    return 0
  fi

  if ! command_exists aws; then
    log_warning "AWS CLI not installed, skipping S3 upload"
    return 0
  fi

  log_info "Uploading to S3: ${s3_path}"
  
  if aws s3 cp \
    "${file}" \
    "s3://${S3_BUCKET}/${s3_path}" \
    --endpoint-url "${S3_ENDPOINT}" \
    --no-verify-ssl; then
    log_success "Uploaded to S3: s3://${S3_BUCKET}/${s3_path}"
  else
    log_error "Failed to upload to S3"
    return 1
  fi
}

cleanup_old_backups() {
  local dir="$1"
  local pattern="$2"

  log_info "Cleaning backups older than ${RETENTION_DAYS} days…"
  
  local deleted
  deleted=$(find "${dir}" -name "${pattern}" -mtime +${RETENTION_DAYS} -delete -print | wc -l)
  
  local remaining
  remaining=$(find "${dir}" -name "${pattern}" | wc -l)
  
  log_success "Cleanup complete (deleted: ${deleted}, remaining: ${remaining})"
}

# ================================
# MYSQL BACKUP
# ================================

backup_mysql() {
  local MYSQL_HOST="${MYSQL_HOST:-mysql}"
  local MYSQL_PORT="${MYSQL_PORT:-3306}"
  local MYSQL_USER="${MYSQL_USER:-root}"
  local MYSQL_PASSWORD="${MYSQL_PASSWORD:?MYSQL_PASSWORD required for MySQL backup}"

  local mysql_backup_dir="${BACKUP_DIR}/mysql"
  local backup_file="mysql-backup-${TIMESTAMP}.sql.gz"
  local backup_path="${mysql_backup_dir}/${backup_file}"

  log_section "MySQL Backup"
  log_info "Host: ${MYSQL_HOST}:${MYSQL_PORT}"
  log_info "Target: ${backup_path}"
  
  # Create backup directory
  mkdir -p "${mysql_backup_dir}"
  
  # Perform backup
  log_info "Creating MySQL dump…"
  if mysqldump \
      -h "${MYSQL_HOST}" \
      -P "${MYSQL_PORT}" \
      -u "${MYSQL_USER}" \
      -p"${MYSQL_PASSWORD}" \
      --single-transaction \
      --routines \
      --triggers \
      --events \
      --all-databases \
      2>/dev/null \
      | gzip > "${backup_path}"; then
    
    local size
    size=$(du -h "${backup_path}" | cut -f1)
    log_success "Backup created: ${backup_file} (${size})"
  else
    log_error "MySQL dump failed"
    return 1
  fi
  
  # Verify integrity
  log_info "Verifying backup integrity…"
  if gunzip -t "${backup_path}"; then
    log_success "Backup integrity verified"
  else
    log_error "Backup integrity check failed"
    return 1
  fi
  
  # Upload to S3
  upload_to_s3 "${backup_path}" "mysql/${backup_file}"
  
  # Create latest symlink
  ln -sf "${backup_path}" "${mysql_backup_dir}/latest.sql.gz"
  
  # Cleanup old backups
  cleanup_old_backups "${mysql_backup_dir}" "mysql-backup-*.sql.gz"
  
  log_success "MySQL backup completed successfully"
}

# ================================
# REDIS BACKUP
# ================================

backup_redis() {
  local REDIS_HOST="${REDIS_HOST:-redis}"
  local REDIS_PORT="${REDIS_PORT:-6379}"
  local REDIS_PASSWORD="${REDIS_PASSWORD:-}"

  local redis_backup_dir="${BACKUP_DIR}/redis"
  local backup_file="redis-backup-${TIMESTAMP}.rdb"
  local backup_path="${redis_backup_dir}/${backup_file}"

  log_section "Redis Backup"
  log_info "Host: ${REDIS_HOST}:${REDIS_PORT}"
  log_info "Target: ${backup_path}"
  
  # Create backup directory
  mkdir -p "${redis_backup_dir}"
  
  # Trigger BGSAVE
  log_info "Triggering background save…"
  local redis_cmd="redis-cli -h ${REDIS_HOST} -p ${REDIS_PORT}"
  [ -n "${REDIS_PASSWORD}" ] && redis_cmd="${redis_cmd} -a ${REDIS_PASSWORD} --no-auth-warning"
  
  if ! ${redis_cmd} BGSAVE &>/dev/null; then
    log_error "Failed to trigger BGSAVE"
    return 1
  fi
  
  # Wait for save to complete
  log_info "Waiting for save to complete…"
  local lastsave
  lastsave=$(${redis_cmd} LASTSAVE)
  
  while true; do
    sleep 1
    local current
    current=$(${redis_cmd} LASTSAVE)
    
    if [ "$current" != "$lastsave" ]; then
      break
    fi
  done
  
  log_success "Background save completed"
  
  # Download RDB file
  log_info "Downloading RDB file…"
  if ${redis_cmd} --rdb "${backup_path}" &>/dev/null; then
    local size
    size=$(du -h "${backup_path}" | cut -f1)
    log_success "Backup created: ${backup_file} (${size})"
  else
    log_error "Failed to download RDB file"
    return 1
  fi
  
  # Upload to S3
  upload_to_s3 "${backup_path}" "redis/${backup_file}"
  
  # Create latest symlink
  ln -sf "${backup_path}" "${redis_backup_dir}/latest.rdb"
  
  # Cleanup old backups
  cleanup_old_backups "${redis_backup_dir}" "redis-backup-*.rdb"
  
  log_success "Redis backup completed successfully"
}

# ================================
# MAIN
# ================================

main() {
  local target="${1:-all}"

  log_section "Backup Service - ${target}"
  log_info "Started: $(timestamp)"
  log_info "Retention: ${RETENTION_DAYS} days"
  
  case "${target}" in
    mysql)
      backup_mysql
      ;;
    redis)
      backup_redis
      ;;
    all)
      backup_mysql
      echo ""
      backup_redis
      ;;
    *)
      log_error "Invalid target: ${target}"
      log_info "Usage: $0 {mysql|redis|all}"
      exit 1
      ;;
  esac
  
  log_section "Backup Complete"
  log_success "All backups completed successfully"
  log_info "Finished: $(timestamp)"
}

main "$@"
