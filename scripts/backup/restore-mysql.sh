#!/bin/bash
# ================================
# MySQL Restore Script
# ================================
# Restores MySQL databases from backup
# Supports local and remote storage (S3, MinIO)

set -eo pipefail

# Configuration
BACKUP_DIR="${BACKUP_DIR:-/backups/mysql}"
BACKUP_FILE="${1:-latest.sql.gz}"

# MySQL connection
MYSQL_HOST="${MYSQL_HOST:-mysql}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_USER="${MYSQL_USER:-root}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:?MYSQL_PASSWORD is required}"

# S3/MinIO configuration (optional)
S3_ENABLED="${S3_ENABLED:-false}"
S3_BUCKET="${S3_BUCKET:-}"
S3_ENDPOINT="${S3_ENDPOINT:-}"

echo "========================================="
echo "MySQL Restore - $(date)"
echo "========================================="
echo "Host: ${MYSQL_HOST}:${MYSQL_PORT}"
echo "Backup file: ${BACKUP_FILE}"
echo ""

# Warning
echo "⚠️  WARNING: This will overwrite existing databases!"
echo ""
read -p "Continue with restore? (yes/no) " -r
if [ "$REPLY" != "yes" ]; then
    echo "Restore cancelled."
    exit 0
fi

# Download from S3 if needed
if [ "${S3_ENABLED}" = "true" ] && [ ! -f "${BACKUP_DIR}/${BACKUP_FILE}" ]; then
    echo ""
    echo "Step 1: Downloading backup from S3/MinIO…"

    if command -v aws &> /dev/null; then
        mkdir -p "${BACKUP_DIR}"
        aws s3 cp \
            "s3://${S3_BUCKET}/mysql/${BACKUP_FILE}" \
            "${BACKUP_DIR}/${BACKUP_FILE}" \
            --endpoint-url "${S3_ENDPOINT}" \
            --no-verify-ssl

        echo "✓ Backup downloaded from S3"
    else
        echo "❌ AWS CLI not installed"
        exit 1
    fi
fi

# Verify backup file exists
if [ ! -f "${BACKUP_DIR}/${BACKUP_FILE}" ]; then
    echo "❌ Backup file not found: ${BACKUP_DIR}/${BACKUP_FILE}"
    exit 1
fi

# Verify backup integrity
echo ""
echo "Step 2: Verifying backup integrity…"
if gunzip -t "${BACKUP_DIR}/${BACKUP_FILE}"; then
    echo "✓ Backup integrity verified"
else
    echo "❌ Backup integrity check failed"
    exit 1
fi

# Perform restore
echo ""
echo "Step 3: Restoring databases…"
echo "This may take several minutes…"

gunzip -c "${BACKUP_DIR}/${BACKUP_FILE}" | \
    mysql \
    -h "${MYSQL_HOST}" \
    -P "${MYSQL_PORT}" \
    -u "${MYSQL_USER}" \
    -p"${MYSQL_PASSWORD}"

echo "✓ Restore completed"

# Verify databases
echo ""
echo "Step 4: Verifying restored databases…"
DATABASES=$(mysql -h "${MYSQL_HOST}" -P "${MYSQL_PORT}" -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" -e "SHOW DATABASES;" | grep -Ev "^(Database|information_schema|performance_schema|mysql|sys)$")

echo "Databases restored:"
echo "${DATABASES}"

echo ""
echo "========================================="
echo "✅ Restore completed successfully"
echo "========================================="
echo ""
