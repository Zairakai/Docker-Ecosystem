#!/usr/bin/env bash
# scripts/pipeline/validate-config.sh
# Validates Docker Ecosystem configuration (Dockerfiles, scripts, directories)
#
# Usage:
#   validate-config.sh
#
# Environment Variables:
#   DEBUG - Enable debug output (default: false)

set -euo pipefail

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck source=scripts/common.sh
source "${SCRIPT_DIR}/../common.sh"

log_section "Validating Docker Ecosystem Configuration"

# Change to project root for consistent path resolution
cd "${PROJECT_ROOT}"

# ================================
# CHECK DOCKERFILES
# ================================
log_info "→ Checking Dockerfiles…"

DOCKERFILE_COUNT=$(find images/ -name "Dockerfile" -type f | wc -l)
log_info "Found ${DOCKERFILE_COUNT} Dockerfiles"

# Verify critical Dockerfiles exist
REQUIRED_DOCKERFILES=(
  "images/php/8.3/Dockerfile"
  "images/node/20/Dockerfile"
  "images/database/mysql/8.0/Dockerfile"
  "images/database/redis/7/Dockerfile"
  "images/web/nginx/1.26/Dockerfile"
)

for dockerfile in "${REQUIRED_DOCKERFILES[@]}"; do
  if [ ! -f "${dockerfile}" ]; then
    log_error "Missing required Dockerfile: ${dockerfile}"
    exit 1
  fi
  log_debug "  ✓ ${dockerfile}"
done

log_success "All required Dockerfiles present"

# ================================
# CHECK SCRIPTS
# ================================
log_info "→ Checking required scripts…"

REQUIRED_SCRIPTS=(
  "scripts/build-all-images.sh"
  "scripts/common.sh"
  "scripts/docker-functions.sh"
  "scripts/promote.sh"
  "scripts/cleanup.sh"
  "scripts/pipeline/build-image.sh"
)

for script in "${REQUIRED_SCRIPTS[@]}"; do
  if [ ! -f "${script}" ]; then
    log_error "Missing required script: ${script}"
    exit 1
  fi

  # Check if script is executable
  if [ ! -x "${script}" ]; then
    log_warning "Script not executable: ${script}"
  fi

  log_debug "  ✓ ${script}"
done

log_success "All required scripts present"

# ================================
# CHECK DIRECTORIES
# ================================
log_info "→ Checking required directories…"

REQUIRED_DIRS=(
  "examples"
  "images/database/mysql/8.0"
  "images/database/redis/7"
  "images/web/nginx/1.26"
  "images/services"
)

for dir in "${REQUIRED_DIRS[@]}"; do
  if [ ! -d "${dir}" ]; then
    log_error "Missing required directory: ${dir}"
    exit 1
  fi
  log_debug "  ✓ ${dir}/"
done

log_success "All required directories present"

# ================================
# CHECK DOCKER COMPOSE EXAMPLES
# ================================
log_info "→ Checking Docker Compose examples…"

REQUIRED_COMPOSE_FILES=(
  "examples/compose/minimal-laravel.yml"
  "examples/compose/docker-compose-ha.yml"
)

for compose_file in "${REQUIRED_COMPOSE_FILES[@]}"; do
  if [ ! -f "${compose_file}" ]; then
    log_warning "Missing Docker Compose example: ${compose_file}"
  else
    log_debug "  ✓ ${compose_file}"
  fi
done

# ================================
# VALIDATE DOCKERFILE SYNTAX
# ================================
log_info "→ Validating Dockerfile syntax…"

while IFS= read -r dockerfile; do
  log_debug "Checking syntax: ${dockerfile}"

  # Check for common issues
  if grep -q "RUN.*&&.*&&.*&&" "${dockerfile}"; then
    log_warning "${dockerfile}: Consider splitting long RUN chains"
  fi

  # Check for COPY/ADD without --chown (security best practice)
  if grep -E "^(COPY|ADD)\s+[^-]" "${dockerfile}" | grep -qv -- "--chown"; then
    log_warning "${dockerfile}: Consider using --chown with COPY/ADD"
  fi

done < <(find images/ -name "Dockerfile" -type f)

log_success "Dockerfile syntax validation passed"

# ================================
# SUMMARY
# ================================
log_section "Configuration Validation Summary"
log_success "✅ Configuration validation passed"
log_info "  - Dockerfiles: ${DOCKERFILE_COUNT} found"
log_info "  - Scripts: ${#REQUIRED_SCRIPTS[@]} validated"
log_info "  - Directories: ${#REQUIRED_DIRS[@]} checked"

exit 0
