#!/usr/bin/env bash
# ================================
# PIPELINE VALIDATION SCRIPT
# ================================
# Pre-flight checks before running CI/CD pipeline
# Orchestrates all validation scripts for comprehensive checking

set -euo pipefail

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common.sh"

log_section "Pipeline Pre-Flight Validation"

# ================================
# TEST 1: Configuration Validation
# ================================
log_section "Test 1: Configuration Validation"

if bash "${SCRIPT_DIR}/pipeline/validate-config.sh"; then
  log_success "Configuration validation passed"
else
  log_error "Configuration validation failed"
  exit 1
fi

# ================================
# TEST 2: ShellCheck Validation
# ================================
log_section "Test 2: ShellCheck Validation"

if bash "${SCRIPT_DIR}/pipeline/validate-shellcheck.sh"; then
  log_success "ShellCheck validation passed"
else
  log_error "ShellCheck validation failed"
  exit 1
fi

# ================================
# TEST 3: Docker Availability
# ================================
log_section "Test 3: Docker Availability"

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
# TEST 4: CI Environment (if applicable)
# ================================
if [ -n "${CI:-}" ]; then
  log_section "Test 4: CI Environment Variables"

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

  # Test registry connectivity
  log_section "Test 5: Registry Connectivity"

  REGISTRY_HOST="${CI_REGISTRY_IMAGE%%/*}"
  log_info "Registry: ${REGISTRY_HOST}"

  if curl -sf "https://${REGISTRY_HOST}" &>/dev/null; then
    log_success "  ✓ Registry reachable"
  else
    log_warning "  ⚠ Registry not reachable (may be expected in local dev)"
  fi
fi

# ================================
# SUMMARY
# ================================
log_section "Validation Summary"

log_success "✅ All pre-flight checks passed!"
log_info ""
log_info "Validated:"
log_info "  • Configuration (Dockerfiles, scripts, directories)"
log_info "  • ShellCheck (100% compliance)"
log_info "  • Docker availability and BuildKit support"

if [ -n "${CI:-}" ]; then
  log_info "  • CI environment variables"
  log_info "  • Registry connectivity"
fi

log_info ""
log_info "Ready to:"
log_info "  • Build images: make build-php-prod"
log_info "  • Test images: make test-all"
log_info "  • Create release: git tag v1.0.0 && git push --tags"
log_info ""
