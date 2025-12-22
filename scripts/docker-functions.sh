#!/usr/bin/env bash
# ================================
# ZAIRAKAI DOCKER ECOSYSTEM
# Docker Build Functions (CI/CD Optimized)
# ================================
# Reusable functions for building and managing Docker images with buildx support
#
# Usage:
#   source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
#   source "$(dirname "${BASH_SOURCE[0]}")/docker-functions.sh"

# Ensure common.sh is sourced first
if ! command -v log_info &>/dev/null; then
    echo "ERROR: common.sh must be sourced before docker-functions.sh" >&2
    exit 1
fi

# ================================
# CONFIGURATION
# ================================
DOCKER_REGISTRY="${DOCKER_REGISTRY:-registry.gitlab.com/zairakai/docker-ecosystem}"
IMAGES_DIR="${IMAGES_DIR:-images}"
PLATFORM="${PLATFORM:-linux/amd64}"
DRY_RUN="${DRY_RUN:-false}"
CACHE_ENABLED="${CACHE_ENABLED:-false}"
NO_CACHE="${NO_CACHE:-false}"
PUSH_TO_REGISTRY="${PUSH_TO_REGISTRY:-false}"
BUILD_ARGS="${BUILD_ARGS:-}"

# ================================
# HELPER FUNCTIONS
# ================================

# Check if Dockerfile exists
check_dockerfile() {
    local dockerfile="$1"

    if [[ ! -f "${dockerfile}" ]]; then
        log_error "Dockerfile not found: ${dockerfile}"
        return 1
    fi

    return 0
}

# Create buildx builder instance
create_buildx_builder() {
    local builder_name="$1"

    log_info "Creating buildx builder: ${builder_name}"

    if docker buildx inspect "${builder_name}" &>/dev/null; then
        log_info "Builder ${builder_name} already exists"
        docker buildx use "${builder_name}"
        return 0
    fi

    docker buildx create \
        --name "${builder_name}" \
        --driver docker-container \
        --use \
        --bootstrap || {
            log_error "Failed to create buildx builder"
            return 1
        }

    log_success "Buildx builder created: ${builder_name}"
    return 0
}

# Remove buildx builder instance
remove_buildx_builder() {
    local builder_name="$1"

    if docker buildx inspect "${builder_name}" &>/dev/null; then
        log_info "Removing buildx builder: ${builder_name}"
        docker buildx rm "${builder_name}" || true
    fi
}

# ================================
# BUILD FUNCTIONS
# ================================

# Build Docker image with buildx (multi-stage support)
#
# Arguments:
#   $1 - Image path relative to IMAGES_DIR (e.g., "php/8.3")
#   $2 - Image name (e.g., "php")
#   $3 - Version tag (e.g., "8.3")
#   $4 - Stage name (optional, e.g., "prod", "dev", "test")
#
# Environment Variables:
#   DOCKER_REGISTRY     - Container registry URL
#   CACHE_ENABLED       - Enable layer caching (true/false)
#   NO_CACHE            - Force rebuild without cache (true/false)
#   PUSH_TO_REGISTRY    - Push image after build (true/false)
#   BUILD_ARGS          - Additional build arguments
#
# Example:
#   build_image_with_buildx "php/8.3" "php" "8.3" "prod"
#   Result: registry.gitlab.com/zairakai/docker-ecosystem/php:8.3-prod
build_image_with_buildx() {
    local image_path="$1"
    local image_name="$2"
    local version_tag="$3"
    local stage="${4:-}"

    local dockerfile="${IMAGES_DIR}/${image_path}/Dockerfile"
    local build_context="${IMAGES_DIR}/${image_path}"

    # Construct full image tag
    local tag_suffix=""
    if [[ -n "${stage}" ]]; then
        tag_suffix="-${stage}"
    fi
    local full_tag="${DOCKER_REGISTRY}/${image_name}:${version_tag}${tag_suffix}"

    # Validate Dockerfile exists
    check_dockerfile "${dockerfile}" || return 1

    log_info "Building ${full_tag}…"
    log_debug "  Dockerfile: ${dockerfile}"
    log_debug "  Context: ${build_context}"
    log_debug "  Platform: ${PLATFORM}"
    if [[ -n "${stage}" ]]; then
        log_debug "  Target: ${stage}"
    fi

    if [[ "${DRY_RUN}" == "true" ]]; then
        log_warning "[DRY-RUN] Would build: ${full_tag}"
        return 0
    fi

    # Build with buildx
    local build_flags=(
        "--platform" "${PLATFORM}"
        "--file" "${dockerfile}"
        "--tag" "${full_tag}"
    )

    # Add target stage if specified
    if [[ -n "${stage}" ]]; then
        build_flags+=("--target" "${stage}")
    fi

    # Cache configuration
    if [[ "${NO_CACHE:-false}" == "true" ]]; then
        log_debug "  Cache: disabled (--no-cache)"
        build_flags+=("--no-cache")
    elif [[ "${CACHE_ENABLED:-false}" == "true" ]]; then
        log_debug "  Cache: enabled (inline + registry)"

        # Try to use previous build as cache
        local cache_tags=(
            "${DOCKER_REGISTRY}/${image_name}:${version_tag}${tag_suffix}"
            "${DOCKER_REGISTRY}/${image_name}:latest${tag_suffix}"
        )

        for cache_tag in "${cache_tags[@]}"; do
            build_flags+=("--cache-from" "${cache_tag}")
        done

        # Enable inline cache for future builds
        build_flags+=("--build-arg" "BUILDKIT_INLINE_CACHE=1")
    fi

    # Additional build arguments
    if [[ -n "${BUILD_ARGS}" ]]; then
        # shellcheck disable=SC2206
        build_flags+=(${BUILD_ARGS})
    fi

    # Push or load
    if [[ "${PUSH_TO_REGISTRY}" == "true" ]]; then
        build_flags+=("--push")
    else
        build_flags+=("--load")
    fi

    # Execute build
    if ! docker buildx build "${build_flags[@]}" "${build_context}"; then
        log_error "Failed to build ${full_tag}"
        return 1
    fi

    log_success "Built ${full_tag}"
    return 0
}

# Build image with multi-version tagging
#
# Creates three tags:
#   - {version}        (e.g., 8.3)
#   - {version}.x      (e.g., 8.3.x)
#   - {version}-latest (e.g., 8.3-latest)
#
# Arguments:
#   $1 - Image path relative to IMAGES_DIR
#   $2 - Image name
#   $3 - Major version
#   $4 - Stage name (optional)
#
# Example:
#   build_with_versions "php/8.3" "php" "8.3" "prod"
build_with_versions() {
    local image_path="$1"
    local image_name="$2"
    local major_version="$3"
    local stage="${4:-}"

    # Build base image
    build_image_with_buildx "${image_path}" "${image_name}" "${major_version}" "${stage}" || return 1

    # Additional version tags are handled by promote.sh in CI/CD
    # For local builds, you can add tagging logic here if needed

    return 0
}

# Legacy compatibility: build_image function
#
# Wraps build_image_with_buildx for backward compatibility
build_image() {
    build_image_with_buildx "$@"
}

# ================================
# PUSH FUNCTIONS
# ================================

# Push Docker image to registry
#
# Arguments:
#   $1 - Full image tag
push_image() {
    local image_tag="$1"

    if [[ "${DRY_RUN}" == "true" ]]; then
        log_warning "[DRY-RUN] Would push: ${image_tag}"
        return 0
    fi

    log_info "Pushing ${image_tag}…"

    if ! docker_push_with_retry "${image_tag}"; then
        log_error "Failed to push ${image_tag}"
        return 1
    fi

    log_success "Pushed ${image_tag}"
    return 0
}

# ================================
# TAGGING FUNCTIONS
# ================================

# Create and optionally push a -latest tag for a service
#
# Arguments:
#   $1 - Service name (e.g., "mailhog", "minio")
tag_service_latest() {
    local service_name="$1"

    local service_tag="${DOCKER_REGISTRY}/services:${service_name}"
    local latest_tag="${DOCKER_REGISTRY}/services:${service_name}-latest"

    if [[ "${DRY_RUN}" == "true" ]]; then
        log_warning "[DRY-RUN] Would tag: ${latest_tag}"
        return 0
    fi

    log_info "Creating latest tag: ${latest_tag}"
    docker tag "${service_tag}" "${latest_tag}" || return 1

    if [[ "${PUSH_TO_REGISTRY}" == "true" ]]; then
        push_image "${latest_tag}"
    fi

    return 0
}

# ================================
# VALIDATION FUNCTIONS
# ================================

# Validate multi-stage build produced expected stages
#
# Arguments:
#   $1 - Image name (e.g., "php")
#   $2 - Version tag (e.g., "8.3")
#   $3+ - Expected stages (e.g., "prod" "dev" "test")
validate_stages() {
    local image_name="$1"
    local version_tag="$2"
    shift 2
    local expected_stages=("$@")

    log_info "Validating stages for ${image_name}:${version_tag}…"

    for stage in "${expected_stages[@]}"; do
        local full_tag="${DOCKER_REGISTRY}/${image_name}:${version_tag}-${stage}"

        if docker manifest inspect "${full_tag}" &>/dev/null; then
            log_success "  ✓ Stage exists: ${stage}"
        else
            log_error "  ✗ Stage missing: ${stage}"
            return 1
        fi
    done

    log_success "All stages validated for ${image_name}:${version_tag}"
    return 0
}

# Export functions
export -f check_dockerfile
export -f create_buildx_builder
export -f remove_buildx_builder
export -f build_image_with_buildx
export -f build_with_versions
export -f build_image
export -f push_image
export -f tag_service_latest
export -f validate_stages
