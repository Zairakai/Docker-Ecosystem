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
# CHECK CRITICAL SCRIPTS (Pipeline-Essential)
# ================================
log_info "→ Checking critical pipeline scripts…"

# Scripts that MUST exist for CI/CD pipeline to work
REQUIRED_SCRIPTS=(
  # Core build system
  "scripts/build-all-images.sh"
  "scripts/common.sh"
  "scripts/docker-functions.sh"
  "scripts/ansi.sh"

  # Core CI/CD pipeline scripts
  "scripts/pipeline/build-image.sh"
  "scripts/pipeline/test-image-sizes.sh"
  "scripts/pipeline/test-multi-stage.sh"
  "scripts/pipeline/sync-dockerhub.sh"
  "scripts/pipeline/validate-config.sh"
  "scripts/pipeline/validate-shellcheck.sh"

  # Core release system
  "scripts/promote.sh"
)

MISSING_CRITICAL=0

for script in "${REQUIRED_SCRIPTS[@]}"; do
  if [ ! -f "${script}" ]; then
    log_error "Missing critical script: ${script}"
    MISSING_CRITICAL=$((MISSING_CRITICAL + 1))
  else
    # Check if script is executable
    if [ ! -x "${script}" ]; then
      log_warning "Script not executable: ${script}"
    fi
    log_debug "  ✓ ${script}"
  fi
done

if [[ ${MISSING_CRITICAL} -gt 0 ]]; then
  log_error "${MISSING_CRITICAL} critical scripts missing"
  exit 1
fi

log_success "All ${#REQUIRED_SCRIPTS[@]} critical scripts present"

# ================================
# CHECK ALL SCRIPTS (Exhaustive)
# ================================
log_info "→ Checking all shell scripts (exhaustive)…"

# Find all .sh scripts (excluding vendor/third-party)
mapfile -t ALL_SCRIPTS < <(find . -name "*.sh" -type f \
  -not -path "*/node_modules/*" \
  -not -path "*/vendor/*" \
  -not -path "*/.git/*" \
  -not -path "*/dist/*" \
  -not -path "*/build/*" \
  -not -path "*/coverage/*" \
  | sort)

TOTAL_SCRIPTS=${#ALL_SCRIPTS[@]}
NON_EXECUTABLE=0

log_info "Found ${TOTAL_SCRIPTS} shell scripts in project"

for script in "${ALL_SCRIPTS[@]}"; do
  if [ ! -x "${script}" ]; then
    log_debug "  ⚠ Not executable: ${script}"
    NON_EXECUTABLE=$((NON_EXECUTABLE + 1))
  fi
done

if [[ ${NON_EXECUTABLE} -gt 0 ]]; then
  log_warning "${NON_EXECUTABLE}/${TOTAL_SCRIPTS} scripts are not executable (chmod +x recommended)"
else
  log_success "All ${TOTAL_SCRIPTS} scripts are executable"
fi

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
log_info ""
log_info "Coverage:"
log_info "  • Dockerfiles: ${DOCKERFILE_COUNT} found"
log_info "  • Critical scripts: ${#REQUIRED_SCRIPTS[@]} validated (pipeline-essential)"
log_info "  • All scripts: ${TOTAL_SCRIPTS} checked (exhaustive)"
log_info "  • Directories: ${#REQUIRED_DIRS[@]} checked"
log_info ""

if [[ ${NON_EXECUTABLE} -gt 0 ]]; then
  log_info "Recommendations:"
  log_info "  • ${NON_EXECUTABLE} scripts could be made executable (chmod +x)"
fi

exit 0
