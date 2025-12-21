#!/bin/bash
# ================================
# CLEANUP STAGING DOCKER TAGS
# ================================
# Removes temporary staging tags (with commit SHA suffix) after successful promotion
# Keeps only stable version tags and latest tags

set -euo pipefail

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common.sh"

# Validate required environment variables
required_vars=(
  "CI_REGISTRY_IMAGE"
  "IMAGE_SUFFIX"
  "CI_PROJECT_ID"
  "CI_REGISTRY_PASSWORD"
)

for var in "${required_vars[@]}"; do
  if [[ -z "${!var:-}" ]]; then
    log_error "Required environment variable $var is not set"
    exit 1
  fi
done

log_section "Cleaning up staging tags with suffix: ${IMAGE_SUFFIX}"

# Extract registry host and project path
REGISTRY_HOST="${CI_REGISTRY_IMAGE%%/*}"
PROJECT_PATH="${CI_REGISTRY_IMAGE#*/}"

log_info "Registry: ${REGISTRY_HOST}"
log_info "Project: ${PROJECT_PATH}"

# Function to delete a specific tag using GitLab API
delete_tag() {
  local repository="$1"
  local tag="$2"

  # URL-encode the repository name
  local encoded_repo
  encoded_repo=$(printf %s "${repository}" | jq -sRr @uri)

  local api_url="https://${REGISTRY_HOST}/api/v4/projects/${CI_PROJECT_ID}/registry/repositories"

  # Get repository ID
  log_info "Finding repository ID for ${repository}…"

  local repo_id
  repo_id=$(curl -sS --fail \
    --header "PRIVATE-TOKEN: ${CI_REGISTRY_PASSWORD}" \
    "${api_url}?tags=true&tags_count=true&name=${encoded_repo}" \
    | jq -r '.[0].id // empty' 2>/dev/null || echo "")

  if [[ -z "${repo_id}" ]]; then
    log_warning "Repository not found: ${repository}"
    return 0
  fi

  log_info "Found repository ID: ${repo_id}"

  # URL-encode the tag name
  local encoded_tag
  encoded_tag=$(printf %s "${tag}" | jq -sRr @uri)

  # Delete the tag
  log_info "Deleting tag: ${repository}:${tag}"
  if curl -sS --fail -X DELETE \
    --header "PRIVATE-TOKEN: ${CI_REGISTRY_PASSWORD}" \
    "${api_url}/${repo_id}/tags/${encoded_tag}" 2>/dev/null; then
    log_success "  ✓ Deleted ${repository}:${tag}"
    return 0
  else
    log_warning "  ✗ Failed to delete ${repository}:${tag} (may not exist)"
    return 1
  fi
}

# Function to clean up staging tags for an image
cleanup_image_stages() {
  local base_name="$1"
  shift
  local stages=("$@")

  for stage in "${stages[@]}"; do
    local tag="${base_name}${IMAGE_SUFFIX}-${stage}"
    delete_tag "${PROJECT_PATH}/${base_name%%:*}" "${tag##*:}" || true
  done
}

# Function to clean up service staging tags
cleanup_service() {
  local base_name="$1"
  local service_name="$2"

  local tag="${service_name}${IMAGE_SUFFIX}"
  delete_tag "${PROJECT_PATH}/${base_name}" "${tag}" || true
}

# Clean up PHP staging tags
log_section "Cleaning PHP staging tags"
cleanup_image_stages "php:8.3" "prod" "dev" "test"

# Clean up Node staging tags
log_section "Cleaning Node staging tags"
cleanup_image_stages "node:20" "prod" "dev" "test"

# Clean up database staging tags
log_section "Cleaning Database staging tags"
cleanup_service "database" "mysql-8.0"
cleanup_service "database" "redis-7"

# Clean up web staging tags
log_section "Cleaning Web staging tags"
cleanup_service "web" "nginx-1.26"

# Clean up application services staging tags
log_section "Cleaning Application Services staging tags"
services=(
  "mailhog"
  "minio"
  "e2e-testing"
  "performance-testing"
)

for service in "${services[@]}"; do
  cleanup_service "services" "${service}"
done

# Optional: Clean up old untagged images (dangling)
log_section "Cleaning up untagged images"

# Get all repositories
repos=$(curl -sS --fail \
  --header "PRIVATE-TOKEN: ${CI_REGISTRY_PASSWORD}" \
  "https://${REGISTRY_HOST}/api/v4/projects/${CI_PROJECT_ID}/registry/repositories" \
  2>/dev/null | jq -r '.[].id' || echo "")

if [[ -n "${repos}" ]]; then
  for repo_id in ${repos}; do
    # Find untagged manifests
    log_info "Checking repository ID ${repo_id} for untagged images…"

    untagged=$(curl -sS --fail \
      --header "PRIVATE-TOKEN: ${CI_REGISTRY_PASSWORD}" \
      "https://${REGISTRY_HOST}/api/v4/projects/${CI_PROJECT_ID}/registry/repositories/${repo_id}/tags?per_page=100" \
      2>/dev/null | jq -r '.[] | select(.name == null) | .digest' || echo "")

    if [[ -n "${untagged}" ]]; then
      while IFS= read -r digest; do
        log_info "Deleting untagged digest: ${digest}"
        curl -sS --fail -X DELETE \
          --header "PRIVATE-TOKEN: ${CI_REGISTRY_PASSWORD}" \
          "https://${REGISTRY_HOST}/api/v4/projects/${CI_PROJECT_ID}/registry/repositories/${repo_id}/tags/${digest}" 2>/dev/null || true
      done <<< "${untagged}"
    fi
  done
fi

# Calculate registry usage
log_section "Registry Statistics"

total_size=0
repo_count=0

if [[ -n "${repos}" ]]; then
  for repo_id in ${repos}; do
    repo_count=$((repo_count + 1))

    tags=$(curl -sS --fail \
      --header "PRIVATE-TOKEN: ${CI_REGISTRY_PASSWORD}" \
      "https://${REGISTRY_HOST}/api/v4/projects/${CI_PROJECT_ID}/registry/repositories/${repo_id}/tags?per_page=100" \
      2>/dev/null | jq -r '.[].total_size' || echo "0")

    for size in ${tags}; do
      total_size=$((total_size + size))
    done
  done
fi

total_size_mb=$((total_size / 1024 / 1024))
log_info "Total repositories: ${repo_count}"
log_info "Total registry size: ${total_size_mb} MB"

log_success "Cleanup completed successfully"
log_info "Staging tags removed, stable version tags retained"
