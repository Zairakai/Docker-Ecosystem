#!/bin/bash
################################################################################
# Disaster Recovery - Manual rollback to previous version
################################################################################
set -euo pipefail

# shellcheck disable=SC1091
# shellcheck disable=SC1091
source "$(dirname "$0")/common.sh"

echo "=========================================="
echo "🚨 Disaster Recovery - Manual Rollback"
echo "=========================================="
echo ""

: "${CI_REGISTRY_IMAGE:?CI_REGISTRY_IMAGE not set}"
: "${ROLLBACK_TAG:?ROLLBACK_TAG not set - specify tag to rollback to}"

echo "⚠️  WARNING: This will rollback images to ${ROLLBACK_TAG}"
echo "This is a MANUAL operation that should only be run in emergencies"
echo ""

# Verify rollback tag exists
echo "🔍 Verifying rollback target…"
if ! docker manifest inspect "${CI_REGISTRY_IMAGE}/php:8.3-${ROLLBACK_TAG}" &>/dev/null; then
    echo "❌ Rollback tag ${ROLLBACK_TAG} not found!"
    exit 1
fi

echo "✓ Rollback target verified"
echo ""

# Rollback function
rollback_image() {
    local base_tag=$1
    local rollback_source="${base_tag}-${ROLLBACK_TAG}"
    local target_tag="${base_tag}-latest"

    echo "🔄 Rolling back: ${target_tag} ← ${rollback_source}"
    docker pull "${CI_REGISTRY_IMAGE}/${rollback_source}"
    docker tag "${CI_REGISTRY_IMAGE}/${rollback_source}" "${CI_REGISTRY_IMAGE}/${target_tag}"
    docker push "${CI_REGISTRY_IMAGE}/${target_tag}"
    echo "  ✓ Rolled back successfully"
}

# Perform rollback
rollback_image "php:8.3"
rollback_image "node:20"
rollback_image "database:mysql-8.0"
rollback_image "database:redis-7"
rollback_image "web:nginx-1.26"

echo ""
echo "✅ Disaster recovery rollback complete!"
echo "📋 Action required: Verify services are working correctly"
