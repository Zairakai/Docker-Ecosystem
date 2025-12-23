#!/usr/bin/env bash
# scripts/pipeline/sync-dockerhub.sh
# Mirrors stable GitLab Registry images to Docker Hub
#
# Usage:
#   sync-dockerhub.sh
#
# Environment Variables:
#   CI_REGISTRY_IMAGE   - GitLab registry image prefix (required)
#   DOCKERHUB_USERNAME  - Docker Hub username (required)
#   DOCKERHUB_TOKEN     - Docker Hub access token (required)

set -euo pipefail

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/common.sh
source "${SCRIPT_DIR}/../common.sh"

# Validate required environment variables
require_envs "CI_REGISTRY_IMAGE" "DOCKERHUB_USERNAME" "DOCKERHUB_TOKEN"

log_section "Mirroring Images to Docker Hub"

log_info "GitLab Registry: ${CI_REGISTRY_IMAGE}"
log_info "Docker Hub User: ${DOCKERHUB_USERNAME}"

# ================================
# LOGIN TO DOCKER HUB
# ================================
log_info "→ Logging in to Docker Hub…"

if echo "${DOCKERHUB_TOKEN}" | docker login -u "${DOCKERHUB_USERNAME}" --password-stdin docker.io; then
  log_success "Logged in to Docker Hub"
else
  log_error "Failed to login to Docker Hub"
  exit 1
fi

# ================================
# DEFINE IMAGE MAPPINGS
# ================================
# Format: "gitlab_tag|dockerhub_tag" (pipe separator to avoid confusion with colons in tags)
IMAGE_MAPPINGS=(
  "php:8.3-prod|zairakai/php:8.3-prod"
  "php:8.3-dev|zairakai/php:8.3-dev"
  "php:8.3-test|zairakai/php:8.3-test"
  "php:latest-prod|zairakai/php:latest-prod"
  "php:latest-dev|zairakai/php:latest-dev"
  "php:latest-test|zairakai/php:latest-test"
  "node:20-prod|zairakai/node:20-prod"
  "node:20-dev|zairakai/node:20-dev"
  "node:20-test|zairakai/node:20-test"
  "node:latest-prod|zairakai/node:latest-prod"
  "node:latest-dev|zairakai/node:latest-dev"
  "node:latest-test|zairakai/node:latest-test"
  "database:mysql-8.0|zairakai/mysql:8.0"
  "database:redis-7|zairakai/redis:7"
  "web:nginx-1.26|zairakai/nginx:1.26"
  "services:mailhog|zairakai/mailhog:latest"
  "services:minio|zairakai/minio:latest"
  "services:e2e-testing|zairakai/e2e-testing:latest"
  "services:performance-testing|zairakai/performance-testing:latest"
)

# ================================
# SYNC IMAGES
# ================================
log_info "→ Syncing ${#IMAGE_MAPPINGS[@]} images to Docker Hub…"

SYNCED=0
FAILED=0

for mapping in "${IMAGE_MAPPINGS[@]}"; do
  # Parse mapping (format: gitlab_tag|dockerhub_tag)
  GITLAB_TAG="${mapping%%|*}"
  DOCKERHUB_TAG="${mapping#*|}"

  GITLAB_IMAGE="${CI_REGISTRY_IMAGE}/${GITLAB_TAG}"

  log_info "Syncing ${GITLAB_TAG} → ${DOCKERHUB_TAG}"

  # Pull from GitLab
  log_debug "  Pulling from GitLab: ${GITLAB_IMAGE}"
  if ! docker pull "${GITLAB_IMAGE}"; then
    log_error "  ✗ Failed to pull ${GITLAB_IMAGE}"
    FAILED=$((FAILED + 1))
    continue
  fi

  # Tag for Docker Hub
  log_debug "  Tagging for Docker Hub: ${DOCKERHUB_TAG}"
  if ! docker tag "${GITLAB_IMAGE}" "${DOCKERHUB_TAG}"; then
    log_error "  ✗ Failed to tag ${DOCKERHUB_TAG}"
    FAILED=$((FAILED + 1))
    continue
  fi

  # Push to Docker Hub
  log_debug "  Pushing to Docker Hub: ${DOCKERHUB_TAG}"
  if ! docker push "${DOCKERHUB_TAG}"; then
    log_error "  ✗ Failed to push ${DOCKERHUB_TAG}"
    FAILED=$((FAILED + 1))
    continue
  fi

  log_success "  ✓ ${DOCKERHUB_TAG} synced"
  SYNCED=$((SYNCED + 1))
done

# ================================
# LOGOUT
# ================================
log_info "→ Logging out from Docker Hub…"
docker logout docker.io || true

# ================================
# SUMMARY
# ================================
log_section "Docker Hub Sync Summary"

if [[ ${FAILED} -eq 0 ]]; then
  log_success "✅ All ${SYNCED} images mirrored to Docker Hub"

  log_info "Available on Docker Hub:"
  log_info "  - docker pull zairakai/php:8.3-prod"
  log_info "  - docker pull zairakai/node:20-prod"
  log_info "  - docker pull zairakai/mysql:8.0"
  log_info "  - docker pull zairakai/redis:7"
  log_info "  - docker pull zairakai/nginx:1.26"
  log_info "  - docker pull zairakai/mailhog:latest"
  log_info "  - docker pull zairakai/minio:latest"
  log_info "  - docker pull zairakai/e2e-testing:latest"
  log_info "  - docker pull zairakai/performance-testing:latest"

  exit 0
else
  log_warning "⚠️  ${SYNCED} images synced, ${FAILED} failed"

  # Don't fail the job, just warn (allow_failure in CI)
  exit 0
fi
