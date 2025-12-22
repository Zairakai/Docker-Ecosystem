#!/usr/bin/env bash
# ================================
# PROMOTE DOCKER IMAGES TO STABLE TAGS
# ================================
# Promotes staging images (with commit SHA suffix) to stable version tags
# Example: php:8.3-abc123-prod → php:8.3-prod, php:8.3.1-prod, php:latest-prod

set -euo pipefail

# Source color utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common.sh"

# Validate required environment variables
required_vars=(
  "CI_REGISTRY_IMAGE"
  "IMAGE_SUFFIX"
  "PROMOTED_VERSION"
)

for var in "${required_vars[@]}"; do
  if [[ -z "${!var:-}" ]]; then
    log_error "Required environment variable $var is not set"
    exit 1
  fi
done

log_info "Promoting images to version: ${PROMOTED_VERSION}"

# Extract version components (e.g., v1.2.3 → 1.2.3, 1.2, 1)
VERSION_FULL="${PROMOTED_VERSION#v}"
VERSION_MAJOR_MINOR="${VERSION_FULL%.*}"
VERSION_MAJOR="${VERSION_MAJOR_MINOR%.*}"

log_info "Version tags: ${VERSION_FULL}, ${VERSION_MAJOR_MINOR}, ${VERSION_MAJOR}"

# Function to promote a single image
promote_image() {
  local source_tag="$1"
  local target_base="$2"
  shift 2
  local stages=("$@")

  for stage in "${stages[@]}"; do
    local source="${CI_REGISTRY_IMAGE}/${target_base}:${source_tag}${IMAGE_SUFFIX}-${stage}"

    log_info "Promoting ${source}…"

    if ! docker pull "${source}"; then
      log_error "Failed to pull source image: ${source}"
      return 1
    fi

    # Tag with version-specific tags
    local tags=(
      "${CI_REGISTRY_IMAGE}/${target_base}:${source_tag}-${stage}"
      "${CI_REGISTRY_IMAGE}/${target_base}:${VERSION_FULL}-${stage}"
      "${CI_REGISTRY_IMAGE}/${target_base}:${VERSION_MAJOR_MINOR}-${stage}"
      "${CI_REGISTRY_IMAGE}/${target_base}:${VERSION_MAJOR}-${stage}"
      "${CI_REGISTRY_IMAGE}/${target_base}:latest-${stage}"
    )

    for tag in "${tags[@]}"; do
      log_info "  → ${tag}"
      docker tag "${source}" "${tag}"

      if ! docker push "${tag}"; then
        log_error "Failed to push tag: ${tag}"
        return 1
      fi
    done
  done

  return 0
}

# Function to promote service images (no stages)
promote_service() {
  local source_tag="$1"
  local target_base="$2"
  local service_name="$3"

  local source="${CI_REGISTRY_IMAGE}/${target_base}:${service_name}${IMAGE_SUFFIX}"

  log_info "Promoting service ${source}…"

  if ! docker pull "${source}"; then
    log_error "Failed to pull source image: ${source}"
    return 1
  fi

  # Tag with version-specific tags
  local tags=(
    "${CI_REGISTRY_IMAGE}/${target_base}:${service_name}"
    "${CI_REGISTRY_IMAGE}/${target_base}:${service_name}-${VERSION_FULL}"
    "${CI_REGISTRY_IMAGE}/${target_base}:${service_name}-${VERSION_MAJOR_MINOR}"
    "${CI_REGISTRY_IMAGE}/${target_base}:${service_name}-${VERSION_MAJOR}"
    "${CI_REGISTRY_IMAGE}/${target_base}:${service_name}-latest"
  )

  for tag in "${tags[@]}"; do
    log_info "  → ${tag}"
    docker tag "${source}" "${tag}"

    if ! docker push "${tag}"; then
      log_error "Failed to push tag: ${tag}"
      return 1
    fi
  done

  return 0
}

# Promote PHP images (prod, dev, test)
log_section "Promoting PHP 8.3 images"
if ! promote_image "8.3" "php" "prod" "dev" "test"; then
  log_error "Failed to promote PHP images"
  exit 1
fi

# Promote Node images (prod, dev, test)
log_section "Promoting Node.js 20 images"
if ! promote_image "20" "node" "prod" "dev" "test"; then
  log_error "Failed to promote Node images"
  exit 1
fi

# Promote database services
log_section "Promoting Database services"
if ! promote_service "mysql-8.0" "database" "mysql-8.0"; then
  log_error "Failed to promote MySQL"
  exit 1
fi

if ! promote_service "redis-7" "database" "redis-7"; then
  log_error "Failed to promote Redis"
  exit 1
fi

# Promote web services
log_section "Promoting Web services"
if ! promote_service "nginx-1.26" "web" "nginx-1.26"; then
  log_error "Failed to promote Nginx"
  exit 1
fi

# Promote application services
log_section "Promoting Application services"
services=(
  "mailhog"
  "minio"
  "e2e-testing"
  "performance-testing"
)

for service in "${services[@]}"; do
  if ! promote_service "${service}" "services" "${service}"; then
    log_error "Failed to promote ${service}"
    exit 1
  fi
done

log_success "All images promoted successfully to version ${PROMOTED_VERSION}"
log_info "Stable tags available:"
log_info "  - ${VERSION_FULL}"
log_info "  - ${VERSION_MAJOR_MINOR}"
log_info "  - ${VERSION_MAJOR}"
log_info "  - latest"
