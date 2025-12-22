#!/usr/bin/env bash
# scripts/pipeline/build-image.sh
# Generic Docker image builder - wrapper around docker-functions.sh
#
# Usage:
#   build-image.sh <image-path> <image-name> <image-tag>
#
# Examples:
#   build-image.sh images/php/8.3 php 8.3-prod
#   build-image.sh images/node/20 node 20-dev
#   build-image.sh images/database/mysql/8.0 database mysql-8.0

set -euo pipefail

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck source=scripts/common.sh
source "${SCRIPT_DIR}/../common.sh"
# shellcheck source=scripts/docker-functions.sh
source "${SCRIPT_DIR}/../docker-functions.sh"

# Arguments
IMAGE_PATH="${1:?ERROR: Missing image path (e.g., images/php/8.3)}"
IMAGE_NAME="${2:?ERROR: Missing image name (e.g., php, node, database)}"
IMAGE_TAG="${3:?ERROR: Missing image tag (e.g., 8.3-prod, mysql-8.0)}"

# Extract relative path from full path (remove "images/" prefix if present)
IMAGE_REL_PATH="${IMAGE_PATH#images/}"

# Extract version and stage from tag
# Examples: 8.3-prod -> version=8.3, stage=prod
#          mysql-8.0 -> version=mysql-8.0, stage=""
VERSION_TAG="${IMAGE_TAG}"
STAGE=""

if [[ "$IMAGE_TAG" =~ -prod$ ]]; then
  VERSION_TAG="${IMAGE_TAG%-prod}"
  STAGE="prod"
elif [[ "$IMAGE_TAG" =~ -dev$ ]]; then
  VERSION_TAG="${IMAGE_TAG%-dev}"
  STAGE="dev"
elif [[ "$IMAGE_TAG" =~ -test$ ]]; then
  VERSION_TAG="${IMAGE_TAG%-test}"
  STAGE="test"
fi

# Setup environment for docker-functions.sh
export IMAGES_DIR="${PROJECT_ROOT}/images"
export DOCKER_REGISTRY="${CI_REGISTRY_IMAGE:-registry.gitlab.com/zairakai/docker-ecosystem}"
export PLATFORM="${PLATFORM:-linux/amd64}"
export CACHE_ENABLED=true
# Respect PUSH_TO_REGISTRY from CI/CD environment, default to true for local builds
export PUSH_TO_REGISTRY="${PUSH_TO_REGISTRY:-true}"
export DRY_RUN="${DRY_RUN:-false}"

# Create unique builder name
export BUILDER_NAME="builder-${IMAGE_NAME//[:\/]/-}-${STAGE:-single}-${CI_PIPELINE_ID:-$$}"

log_section "Building Docker Image"
log_info "Image: ${IMAGE_NAME}:${IMAGE_TAG}"
log_info "Path: ${IMAGE_PATH}"
log_info "Registry: ${DOCKER_REGISTRY}"
if [[ -n "${STAGE}" ]]; then
  log_info "Stage: ${STAGE}"
fi

# Create buildx builder
if ! create_buildx_builder "${BUILDER_NAME}"; then
  log_error "Failed to create buildx builder"
  exit 1
fi

# Build with docker-functions.sh
if build_image_with_buildx "${IMAGE_REL_PATH}" "${IMAGE_NAME}" "${VERSION_TAG}" "${STAGE}"; then
  log_success "Build complete: ${IMAGE_NAME}:${IMAGE_TAG}"
else
  log_error "Build failed: ${IMAGE_NAME}:${IMAGE_TAG}"
  remove_buildx_builder "${BUILDER_NAME}"
  exit 1
fi

# Cleanup builder
remove_buildx_builder "${BUILDER_NAME}"

log_section "Build Complete"
log_success "✅ ${IMAGE_NAME}:${IMAGE_TAG} built successfully"
