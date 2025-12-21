#!/bin/bash
# ================================
# Redis Backup Script
# ================================
# Creates backups of Redis RDB files
# Supports local and remote storage (S3, MinIO)

set -eo pipefail

# Configuration
BACKUP_DIR="${BACKUP_DIR:-/backups/redis}"
RETENTION_DAYS="${RETENTION_DAYS:-7}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="redis-backup-${TIMESTAMP}.rdb"

# Redis connection
REDIS_HOST="${REDIS_HOST:-redis}"
REDIS_PORT="${REDIS_PORT:-6379}"
REDIS_PASSWORD="${REDIS_PASSWORD:-}"

# S3/MinIO configuration (optional)
S3_ENABLED="${S3_ENABLED:-false}"
S3_BUCKET="${S3_BUCKET:-}"
S3_ENDPOINT="${S3_ENDPOINT:-}"

echo "========================================="
echo "Redis Backup - $(date)"
echo "========================================="
echo "Host: ${REDIS_HOST}:${REDIS_PORT}"
echo "Backup Directory: ${BACKUP_DIR}"
echo "Retention: ${RETENTION_DAYS} days"
echo ""

# Create backup directory
mkdir -p "${BACKUP_DIR}"

# Trigger BGSAVE
echo "Step 1: Triggering background save…"
if [ -n "${REDIS_PASSWORD}" ]; then
    redis-cli -h "${REDIS_HOST}" -p "${REDIS_PORT}" -a "${REDIS_PASSWORD}" BGSAVE
else
    redis-cli -h "${REDIS_HOST}" -p "${REDIS_PORT}" BGSAVE
fi

# Wait for save to complete
echo "Step 2: Waiting for save to complete…"
while true; do
    if [ -n "${REDIS_PASSWORD}" ]; then
        LASTSAVE=$(redis-cli -h "${REDIS_HOST}" -p "${REDIS_PORT}" -a "${REDIS_PASSWORD}" LASTSAVE)
    else
        LASTSAVE=$(redis-cli -h "${REDIS_HOST}" -p "${REDIS_PORT}" LASTSAVE)
    fi

    sleep 1

    if [ -n "${REDIS_PASSWORD}" ]; then
        CURRENT=$(redis-cli -h "${REDIS_HOST}" -p "${REDIS_PORT}" -a "${REDIS_PASSWORD}" LASTSAVE)
    else
        CURRENT=$(redis-cli -h "${REDIS_HOST}" -p "${REDIS_PORT}" LASTSAVE)
    fi

    if [ "$CURRENT" != "$LASTSAVE" ]; then
        break
    fi
done

echo "✓ Save completed"

# Copy RDB file
echo ""
echo "Step 3: Copying RDB file…"

# Note: In a real scenario, you'd copy from the Redis data volume
# For Docker, you can use: docker cp redis:/data/dump.rdb ${BACKUP_DIR}/${BACKUP_FILE}

if [ -n "${REDIS_PASSWORD}" ]; then
    redis-cli -h "${REDIS_HOST}" -p "${REDIS_PORT}" -a "${REDIS_PASSWORD}" --rdb "${BACKUP_DIR}/${BACKUP_FILE}"
else
    redis-cli -h "${REDIS_HOST}" -p "${REDIS_PORT}" --rdb "${BACKUP_DIR}/${BACKUP_FILE}"
fi

BACKUP_SIZE=$(du -h "${BACKUP_DIR}/${BACKUP_FILE}" | cut -f1)
echo "✓ Backup created: ${BACKUP_FILE} (${BACKUP_SIZE})"

# Upload to S3/MinIO (if enabled)
if [ "${S3_ENABLED}" = "true" ]; then
    echo ""
    echo "Step 4: Uploading to S3/MinIO…"

    if command -v aws &> /dev/null; then
        aws s3 cp \
            "${BACKUP_DIR}/${BACKUP_FILE}" \
            "s3://${S3_BUCKET}/redis/${BACKUP_FILE}" \
            --endpoint-url "${S3_ENDPOINT}" \
            --no-verify-ssl

        echo "✓ Backup uploaded to S3: s3://${S3_BUCKET}/redis/${BACKUP_FILE}"
    else
        echo "⚠️  AWS CLI not installed, skipping S3 upload"
    fi
fi

# Clean old backups
echo ""
echo "Step 5: Cleaning old backups (older than ${RETENTION_DAYS} days)…"
find "${BACKUP_DIR}" -name "redis-backup-*.rdb" -mtime +${RETENTION_DAYS} -delete
REMAINING=$(find "${BACKUP_DIR}" -name "redis-backup-*.rdb" | wc -l)
echo "✓ Cleanup complete (${REMAINING} backups remaining)"

# Create latest symlink
ln -sf "${BACKUP_DIR}/${BACKUP_FILE}" "${BACKUP_DIR}/latest.rdb"

echo ""
echo "========================================="
echo "✅ Backup completed successfully"
echo "========================================="
echo "Backup file: ${BACKUP_DIR}/${BACKUP_FILE}"
echo "Size: ${BACKUP_SIZE}"
echo ""
