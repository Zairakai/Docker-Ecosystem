#!/usr/bin/env bash
################################################################################
# Disaster Recovery - Manual rollback to previous version
################################################################################
# Usage:
#   ROLLBACK_TAG=prod disaster-recovery.sh
#
# Environment Variables:
#   CI_REGISTRY_IMAGE - Registry image prefix (required)
#   ROLLBACK_TAG      - Tag to rollback to (required)

set -euo pipefail

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common.sh"

log_section "Disaster Recovery - Manual Rollback"

require_envs "CI_REGISTRY_IMAGE" "ROLLBACK_TAG"

log_warning "This will rollback images to ${ROLLBACK_TAG}"
log_warning "This is a MANUAL operation that should only be run in emergencies"

# Verify rollback tag exists
log_info "Verifying rollback target…"
if ! docker manifest inspect "${CI_REGISTRY_IMAGE}/php:8.3-${ROLLBACK_TAG}" &>/dev/null; then
    log_error "Rollback tag ${ROLLBACK_TAG} not found!"
    exit 1
fi

log_success "Rollback target verified"

# Rollback function
rollback_image() {
    local base_tag=$1
    local rollback_source="${base_tag}-${ROLLBACK_TAG}"
    local target_tag="${base_tag}-latest"

    log_info "Rolling back: ${target_tag} ← ${rollback_source}"

    if ! docker pull "${CI_REGISTRY_IMAGE}/${rollback_source}"; then
        log_error "Failed to pull ${rollback_source}"
        return 1
    fi

    docker tag "${CI_REGISTRY_IMAGE}/${rollback_source}" "${CI_REGISTRY_IMAGE}/${target_tag}"

    if ! docker push "${CI_REGISTRY_IMAGE}/${target_tag}"; then
        log_error "Failed to push ${target_tag}"
        return 1
    fi

    log_success "Rolled back: ${target_tag}"
}

# Perform rollback
log_section "Rolling Back Images"

rollback_image "php:8.3"
rollback_image "node:20"
rollback_image "database:mysql-8.0"
rollback_image "database:redis-7"
rollback_image "web:nginx-1.26"

log_section "Rollback Complete"
log_success "Disaster recovery rollback complete!"
log_warning "Action required: Verify services are working correctly"
