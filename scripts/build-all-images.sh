#!/usr/bin/env bash

# ================================
# ZAIRAKAI DOCKER ECOSYSTEM
# Build All Images
# ================================
# Builds and optionally pushes all Docker images to GitLab Container Registry
#
# Usage:
#   ./build-all-images.sh                      # Build only
#   DRY_RUN=true ./build-all-images.sh
#   DEBUG=true ./build-all-images.sh
#
# Environment Variables:
#   DOCKER_REGISTRY   - Container registry URL (default: registry.gitlab.com/zairakai/docker-ecosystem)
#   PLATFORM          - Target platform (default: linux/amd64)
#   BUILD_ARGS        - Additional docker build arguments
#   DRY_RUN           - Show what would be built without building (default: false)
#   DEBUG             - Enable debug output (default: false)
#
# Cache Options:
#   CACHE_ENABLED=true  - Enable Docker layer caching (pulls existing images for reuse)
#   NO_CACHE=true       - Force complete rebuild without cache (overrides CACHE_ENABLED)
#
# Cache Examples:
#   CACHE_ENABLED=true ./build-all-images.sh   # Use cache for faster builds
#   NO_CACHE=true ./build-all-images.sh        # Force fresh rebuild (for debugging)

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/ansi.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/docker-functions.sh"

# ================================
# BUILD SECTIONS
# ================================

build_php_stack() {
    log "Building PHP Stack…"
    echo
    build_with_versions "php/8.3" "php" "8.3" "prod"
    build_with_versions "php/8.3" "php" "8.3" "dev"
    build_with_versions "php/8.3" "php" "8.3" "test"
}

build_node_stack() {
    log "Building Node.js Stack…"
    echo
    build_with_versions "node/20" "node" "20" "prod"
    build_with_versions "node/20" "node" "20" "dev"
    build_with_versions "node/20" "node" "20" "test"
}

build_database_services() {
    log "Building Database Services…"
    echo
    build_with_versions "database/mysql/8.0" "database" "mysql-8.0"
    build_with_versions "database/redis/7" "database" "redis-7"
}

build_web_services() {
    log "Building Web Services…"
    echo
    build_with_versions "web/nginx/1.26" "web" "nginx-1.26"
}

build_support_services() {
    log "Building Support Services…"
    echo
    build_image "services/mailhog" "services" "mailhog"
    build_image "services/minio" "services" "minio"
    build_image "services/e2e-testing" "services" "e2e-testing"
    build_image "services/performance-testing" "services" "performance-testing"

    # Create latest tags
    for service in mailhog minio e2e-testing performance-testing; do
        tag_service_latest "${service}"
    done
}

print_summary() {
    separator "="
    ok "BUILD COMPLETE!"
    separator "="
    log "Images built:"
    log "  • PHP: 8.3 (prod, dev, test)"
    log "  • Node.js: 20 (prod, dev, test)"
    log "  • Database: MySQL 8.0, Redis 7"
    log "  • Web: Nginx 1.26"
    log "  • Services: MailHog, MinIO, E2E Testing, Performance Testing"
    echo
}

# ================================
# MAIN BUILD PROCESS
# ================================

main() {
    log "================================="
    log "ZAIRAKAI DOCKER ECOSYSTEM - BUILD"
    log "================================="
    log "Registry:  ${DOCKER_REGISTRY}"
    log "Platform:  ${PLATFORM}"
    if [[ "${NO_CACHE}" == "true" ]]; then
        log "Cache:     disabled (NO_CACHE=true)"
    elif [[ "${CACHE_ENABLED}" == "true" ]]; then
        log "Cache:     enabled (inline)"
    else
        log "Cache:     default"
    fi
    log "Dry Run:   ${DRY_RUN}"
    log "Debug:     ${DEBUG}"
    log "================================="

    cd "${PROJECT_ROOT}" || error "Failed to change to project root"

    # Build all stacks
    build_php_stack
    build_node_stack
    build_database_services
    build_web_services
    build_support_services

    # Print summary
    print_summary
}

# ================================
# EXECUTION
# ================================

main "$@"
