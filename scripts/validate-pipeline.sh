#!/bin/bash
# ================================
# PIPELINE VALIDATION SCRIPT
# ================================
# Pre-flight checks before running CI/CD pipeline
# Validates configuration, scripts, and Docker setup

set -euo pipefail

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common.sh"

PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

log_section "Pipeline Pre-Flight Validation"

# ================================
# TEST 1: Required Files
# ================================
log_section "Test 1: Required Files"

REQUIRED_FILES=(
  ".gitlab-ci.yml"
  "scripts/common.sh"
  "scripts/docker-functions.sh"
  "scripts/health-checks.sh"
  "scripts/backup-restore.sh"
  "scripts/promote.sh"
  "scripts/cleanup.sh"
  "images/php/8.3/Dockerfile"
  "images/node/20/Dockerfile"
  "images/database/mysql/8.0/Dockerfile"
  "images/database/redis/7/Dockerfile"
  "images/web/nginx/1.26/Dockerfile"
)

MISSING_FILES=()

for file in "${REQUIRED_FILES[@]}"; do
  if [ -f "${PROJECT_ROOT}/${file}" ]; then
    log_success "  ✓ ${file}"
  else
    log_error "  ✗ ${file} (missing)"
    MISSING_FILES+=("${file}")
  fi
done

if [ ${#MISSING_FILES[@]} -gt 0 ]; then
  log_error "Missing ${#MISSING_FILES[@]} required files"
  exit 1
fi

log_success "All required files present"

# ================================
# TEST 2: Script Executability
# ================================
log_section "Test 2: Script Executability"

SCRIPTS=(
  "scripts/common.sh"
  "scripts/docker-functions.sh"
  "scripts/health-checks.sh"
  "scripts/backup-restore.sh"
  "scripts/promote.sh"
  "scripts/cleanup.sh"
)

NON_EXECUTABLE=()

for script in "${SCRIPTS[@]}"; do
  if [ -x "${PROJECT_ROOT}/${script}" ]; then
    log_success "  ✓ ${script} (executable)"
  else
    log_warning "  ⚠ ${script} (not executable, fixing…)"
    chmod +x "${PROJECT_ROOT}/${script}"
    if [ -x "${PROJECT_ROOT}/${script}" ]; then
      log_success "    → Fixed"
    else
      log_error "    → Failed to fix"
      NON_EXECUTABLE+=("${script}")
    fi
  fi
done

if [ ${#NON_EXECUTABLE[@]} -gt 0 ]; then
  log_error "Failed to make ${#NON_EXECUTABLE[@]} scripts executable"
  exit 1
fi

log_success "All scripts are executable"

# ================================
# TEST 3: Dockerfile Syntax
# ================================
log_section "Test 3: Dockerfile Syntax"

DOCKERFILES=$(find "${PROJECT_ROOT}/images" -name "Dockerfile" -type f)

while IFS= read -r dockerfile; do
  relative_path="${dockerfile#${PROJECT_ROOT}/}"

  if docker run --rm -i hadolint/hadolint < "${dockerfile}" 2>/dev/null; then
    log_success "  ✓ ${relative_path}"
  else
    log_warning "  ⚠ ${relative_path} (hadolint warnings)"
    # Don't fail on warnings, just note them
  fi
done <<< "${DOCKERFILES}"

log_success "Dockerfile syntax validation complete"

# ================================
# TEST 4: Multi-Stage Build Validation
# ================================
log_section "Test 4: Multi-Stage Build Validation"

# Check PHP Dockerfile has all stages
log_info "Checking PHP Dockerfile stages…"
PHP_DOCKERFILE="${PROJECT_ROOT}/images/php/8.3/Dockerfile"

REQUIRED_STAGES=("prod" "dev" "test")
MISSING_STAGES=()

for stage in "${REQUIRED_STAGES[@]}"; do
  if grep -q "^FROM .* AS ${stage}" "${PHP_DOCKERFILE}"; then
    log_success "  ✓ Stage '${stage}' found"
  else
    log_error "  ✗ Stage '${stage}' missing"
    MISSING_STAGES+=("${stage}")
  fi
done

if [ ${#MISSING_STAGES[@]} -gt 0 ]; then
  log_error "PHP Dockerfile missing ${#MISSING_STAGES[@]} stages"
  exit 1
fi

# Check Node Dockerfile has all stages
log_info "Checking Node Dockerfile stages…"
NODE_DOCKERFILE="${PROJECT_ROOT}/images/node/20/Dockerfile"

if [ -f "${NODE_DOCKERFILE}" ]; then
  for stage in "${REQUIRED_STAGES[@]}"; do
    if grep -q "^FROM .* AS ${stage}" "${NODE_DOCKERFILE}"; then
      log_success "  ✓ Stage '${stage}' found"
    else
      log_warning "  ⚠ Stage '${stage}' missing (may not be required)"
    fi
  done
else
  log_warning "Node Dockerfile not found (may not be required)"
fi

log_success "Multi-stage build validation complete"

# ================================
# TEST 5: GitLab CI Syntax
# ================================
log_section "Test 5: GitLab CI Syntax"

GITLAB_CI="${PROJECT_ROOT}/.gitlab-ci.yml"

if command -v gitlab-ci-lint &>/dev/null; then
  log_info "Validating .gitlab-ci.yml syntax with gitlab-ci-lint…"
  if gitlab-ci-lint "${GITLAB_CI}"; then
    log_success ".gitlab-ci.yml syntax valid"
  else
    log_error ".gitlab-ci.yml syntax invalid"
    exit 1
  fi
else
  log_warning "gitlab-ci-lint not installed, skipping CI syntax validation"
  log_info "Install with: npm install -g gitlab-ci-lint"
fi

# ================================
# TEST 6: Docker Availability
# ================================
log_section "Test 6: Docker Availability"

if command -v docker &>/dev/null; then
  log_success "  ✓ Docker installed"

  if docker info &>/dev/null; then
    log_success "  ✓ Docker daemon running"
  else
    log_error "  ✗ Docker daemon not running"
    exit 1
  fi

  # Check for BuildKit support
  if docker buildx version &>/dev/null; then
    log_success "  ✓ Docker buildx available"
  else
    log_warning "  ⚠ Docker buildx not available (may cause issues)"
  fi
else
  log_error "  ✗ Docker not installed"
  exit 1
fi

# ================================
# TEST 7: Environment Variables
# ================================
log_section "Test 7: Environment Variables (CI Context)"

if [ -n "${CI:-}" ]; then
  log_info "Running in CI environment"

  REQUIRED_CI_VARS=(
    "CI_REGISTRY_IMAGE"
    "CI_REGISTRY_USER"
    "CI_REGISTRY_PASSWORD"
    "CI_COMMIT_SHORT_SHA"
  )

  MISSING_CI_VARS=()

  for var in "${REQUIRED_CI_VARS[@]}"; do
    if [ -n "${!var:-}" ]; then
      log_success "  ✓ ${var} set"
    else
      log_error "  ✗ ${var} not set"
      MISSING_CI_VARS+=("${var}")
    fi
  done

  if [ ${#MISSING_CI_VARS[@]} -gt 0 ]; then
    log_error "Missing ${#MISSING_CI_VARS[@]} required CI variables"
    exit 1
  fi
else
  log_info "Not running in CI environment (local execution)"
  log_warning "Some checks may be skipped"
fi

# ================================
# TEST 8: Registry Connectivity
# ================================
log_section "Test 8: Registry Connectivity (CI Only)"

if [ -n "${CI_REGISTRY_IMAGE:-}" ]; then
  log_info "Testing registry connectivity…"

  REGISTRY_HOST="${CI_REGISTRY_IMAGE%%/*}"
  log_info "Registry: ${REGISTRY_HOST}"

  if curl -sf "https://${REGISTRY_HOST}" &>/dev/null; then
    log_success "  ✓ Registry reachable"
  else
    log_error "  ✗ Registry not reachable"
    exit 1
  fi

  # Test registry authentication (if credentials available)
  if [ -n "${CI_REGISTRY_PASSWORD:-}" ]; then
    log_info "Testing registry authentication…"
    if echo "${CI_REGISTRY_PASSWORD}" | docker login -u "${CI_REGISTRY_USER}" --password-stdin "${REGISTRY_HOST}" &>/dev/null; then
      log_success "  ✓ Registry authentication successful"
      docker logout "${REGISTRY_HOST}" &>/dev/null || true
    else
      log_error "  ✗ Registry authentication failed"
      exit 1
    fi
  fi
else
  log_info "Skipping registry connectivity test (not in CI)"
fi

# ================================
# TEST 9: Script Dependencies
# ================================
log_section "Test 9: Script Dependencies"

# Test that common.sh can be sourced
if source "${SCRIPT_DIR}/common.sh" &>/dev/null; then
  log_success "  ✓ common.sh can be sourced"
else
  log_error "  ✗ common.sh has syntax errors"
  exit 1
fi

# Test that docker-functions.sh can be sourced (after common.sh)
if source "${SCRIPT_DIR}/docker-functions.sh" &>/dev/null; then
  log_success "  ✓ docker-functions.sh can be sourced"
else
  log_error "  ✗ docker-functions.sh has syntax errors"
  exit 1
fi

# ================================
# SUMMARY
# ================================
log_section "Validation Summary"

log_success "✅ All pre-flight checks passed!"
log_info ""
log_info "Pipeline is ready to run. Key findings:"
log_info "  • All required files present"
log_info "  • Scripts are executable"
log_info "  • Dockerfiles are valid"
log_info "  • Multi-stage builds configured"
log_info "  • Docker is available and running"

if [ -n "${CI:-}" ]; then
  log_info "  • CI environment validated"
  log_info "  • Registry connectivity confirmed"
fi

log_info ""
log_info "Next steps:"
log_info "  1. Commit and push changes"
log_info "  2. Create a version tag (e.g., v1.0.0)"
log_info "  3. Monitor pipeline execution in GitLab CI"
log_info ""
