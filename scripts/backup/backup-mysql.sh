#!/bin/bash
# ================================
# MySQL Backup Script
# ================================
# Creates compressed backups of MySQL databases
# Supports local and remote storage (S3, MinIO)

set -eo pipefail

# Source ANSI helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../ansi.sh"

# Configuration
BACKUP_DIR="${BACKUP_DIR:-/backups/mysql}"
RETENTION_DAYS="${RETENTION_DAYS:-7}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="mysql-backup-${TIMESTAMP}.sql.gz"

# MySQL connection
MYSQL_HOST="${MYSQL_HOST:-mysql}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_USER="${MYSQL_USER:-root}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:?MYSQL_PASSWORD is required}"

# S3/MinIO configuration (optional)
S3_ENABLED="${S3_ENABLED:-false}"
S3_BUCKET="${S3_BUCKET:-}"
S3_ENDPOINT="${S3_ENDPOINT:-}"
S3_ACCESS_KEY="${S3_ACCESS_KEY:-}"
S3_SECRET_KEY="${S3_SECRET_KEY:-}"

printf "%b%s%b\n" "${FG_BLUE}" "$(printf '=%.0s' {1..70})" "${RESET}"
info "MySQL Backup - $(date)"
printf "%b%s%b\n" "${FG_BLUE}" "$(printf '=%.0s' {1..70})" "${RESET}"
info "Host: ${MYSQL_HOST}:${MYSQL_PORT}"
info "Backup Directory: ${BACKUP_DIR}"
info "Retention: ${RETENTION_DAYS} days"
printf "\n"

# Create backup directory
mkdir -p "${BACKUP_DIR}"

# Perform backup
info "Step 1: Creating backup…"
mysqldump \
    -h "${MYSQL_HOST}" \
    -P "${MYSQL_PORT}" \
    -u "${MYSQL_USER}" \
    -p"${MYSQL_PASSWORD}" \
    --single-transaction \
    --routines \
    --triggers \
    --events \
    --all-databases \
    | gzip > "${BACKUP_DIR}/${BACKUP_FILE}"

BACKUP_SIZE=$(du -h "${BACKUP_DIR}/${BACKUP_FILE}" | cut -f1)
ok "Backup created: ${BACKUP_FILE} (${BACKUP_SIZE})"

# Verify backup integrity
printf "\n"
info "Step 2: Verifying backup integrity…"
if gunzip -t "${BACKUP_DIR}/${BACKUP_FILE}"; then
    ok "Backup integrity verified"
else
    err "Backup integrity check failed"
    exit 1
fi

# Upload to S3/MinIO (if enabled)
if [ "${S3_ENABLED}" = "true" ]; then
    printf "\n"
    info "Step 3: Uploading to S3/MinIO…"

    if command -v aws &> /dev/null; then
        aws s3 cp \
            "${BACKUP_DIR}/${BACKUP_FILE}" \
            "s3://${S3_BUCKET}/mysql/${BACKUP_FILE}" \
            --endpoint-url "${S3_ENDPOINT}" \
            --no-verify-ssl

        ok "Backup uploaded to S3: s3://${S3_BUCKET}/mysql/${BACKUP_FILE}"
    else
        warn "AWS CLI not installed, skipping S3 upload"
    fi
fi

# Clean old backups
printf "\n"
info "Step 4: Cleaning old backups (older than ${RETENTION_DAYS} days)…"
find "${BACKUP_DIR}" -name "mysql-backup-*.sql.gz" -mtime +${RETENTION_DAYS} -delete
REMAINING=$(find "${BACKUP_DIR}" -name "mysql-backup-*.sql.gz" | wc -l)
ok "Cleanup complete (${REMAINING} backups remaining)"

# Create latest symlink
ln -sf "${BACKUP_DIR}/${BACKUP_FILE}" "${BACKUP_DIR}/latest.sql.gz"

printf "\n"
printf "%b%s%b\n" "${FG_BLUE}" "$(printf '=%.0s' {1..70})" "${RESET}"
ok "Backup completed successfully"
printf "%b%s%b\n" "${FG_BLUE}" "$(printf '=%.0s' {1..70})" "${RESET}"
info "Backup file: ${BACKUP_DIR}/${BACKUP_FILE}"
info "Size: ${BACKUP_SIZE}"
printf "\n"
