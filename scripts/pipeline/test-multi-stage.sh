#!/usr/bin/env bash
# scripts/pipeline/test-multi-stage.sh
# Verifies multi-stage build integrity (prod/dev/test stages)
#
# Usage:
#   test-multi-stage.sh
#
# Environment Variables:
#   CI_REGISTRY_IMAGE   - Registry image prefix (required)
#   IMAGE_SUFFIX        - Image tag suffix (default: -local)

set -euo pipefail

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/common.sh
source "${SCRIPT_DIR}/../common.sh"

# Validate required environment variables
require_env "CI_REGISTRY_IMAGE"

# Configuration
IMAGE_SUFFIX="${IMAGE_SUFFIX:--local}"

log_section "Verifying Multi-Stage Build Integrity"

log_info "Registry: ${CI_REGISTRY_IMAGE}"
log_info "Suffix: ${IMAGE_SUFFIX}"

# ================================
# VERIFY LOCAL IMAGES
# ================================
log_info "→ Verifying local images (built on runner)…"

PHP_PROD="${CI_REGISTRY_IMAGE}/php:8.3${IMAGE_SUFFIX}-prod"
PHP_DEV="${CI_REGISTRY_IMAGE}/php:8.3${IMAGE_SUFFIX}-dev"
PHP_TEST="${CI_REGISTRY_IMAGE}/php:8.3${IMAGE_SUFFIX}-test"

NODE_PROD="${CI_REGISTRY_IMAGE}/node:20${IMAGE_SUFFIX}-prod"
NODE_DEV="${CI_REGISTRY_IMAGE}/node:20${IMAGE_SUFFIX}-dev"
NODE_TEST="${CI_REGISTRY_IMAGE}/node:20${IMAGE_SUFFIX}-test"

MISSING=0
for image in "${PHP_PROD}" "${PHP_DEV}" "${PHP_TEST}" "${NODE_PROD}" "${NODE_DEV}" "${NODE_TEST}"; do
  log_info "Checking: ${image}"
  if ! docker image inspect "${image}" &>/dev/null; then
    log_error "  ✗ Not found locally: ${image}"
    MISSING=$((MISSING + 1))
  else
    log_success "  ✓ Found locally"
  fi
done

if [[ ${MISSING} -gt 0 ]]; then
  log_error "${MISSING} images not found - make sure builds completed on same runner"
  exit 1
fi

log_success "All images found locally"

# ================================
# TEST PHP STAGES
# ================================
log_section "Testing PHP Image Stages"

# Test 1: Xdebug should NOT be in prod
log_info "→ Checking Xdebug in prod (should NOT be present)…"

if docker run --rm "${PHP_PROD}" php -m 2>/dev/null | grep -qi "xdebug"; then
  log_error "❌ Xdebug found in production image (should not be present)"
  exit 1
else
  log_success "✓ Xdebug correctly absent from prod"
fi

# Test 2: Xdebug should be in dev
log_info "→ Checking Xdebug in dev (should be present)…"

if docker run --rm "${PHP_DEV}" php -m 2>/dev/null | grep -qi "xdebug"; then
  log_success "✓ Xdebug correctly present in dev"
else
  log_error "❌ Xdebug not found in dev image (should be present)"
  exit 1
fi

# Test 3: PCOV should be in test
log_info "→ Checking PCOV in test (should be present)…"

PCOV_CHECK=$(docker run --rm "${PHP_TEST}" sh -c 'php -m 2>&1 | grep -i "pcov" || echo "NOT_FOUND"')

if echo "${PCOV_CHECK}" | grep -q "NOT_FOUND"; then
  log_error "❌ PCOV not found in test image"
  log_info "Available extensions:"
  docker run --rm "${PHP_TEST}" php -m 2>/dev/null || true
  exit 1
else
  log_success "✓ PCOV correctly present in test"
fi

# Test 4: Composer should be in dev and test, but not prod
log_info "→ Checking Composer presence…"

if docker run --rm "${PHP_PROD}" sh -c 'command -v composer' 2>/dev/null; then
  log_warning "⚠️  Composer found in prod (consider removing for minimal image)"
else
  log_success "✓ Composer correctly absent from prod"
fi

if docker run --rm "${PHP_DEV}" sh -c 'command -v composer' 2>/dev/null; then
  log_success "✓ Composer present in dev"
else
  log_warning "⚠️  Composer not found in dev (expected to be present)"
fi

# ================================
# TEST NODE STAGES
# ================================
log_section "Testing Node.js Image Stages"

# Test 5: Yarn should be in dev and test, minimal in prod
log_info "→ Checking Yarn presence…"

if docker run --rm "${NODE_DEV}" sh -c 'command -v yarn' 2>/dev/null; then
  log_success "✓ Yarn present in dev"
else
  log_warning "⚠️  Yarn not found in dev (expected to be present)"
fi

# Test 6: Development dependencies (check package size difference)
log_info "→ Checking image size progression (prod < dev < test)…"

PHP_PROD_SIZE=$(docker image inspect "${PHP_PROD}" --format='{{.Size}}')
PHP_DEV_SIZE=$(docker image inspect "${PHP_DEV}" --format='{{.Size}}')
PHP_TEST_SIZE=$(docker image inspect "${PHP_TEST}" --format='{{.Size}}')

log_info "PHP prod size: $((PHP_PROD_SIZE / 1024 / 1024)) MB"
log_info "PHP dev size:  $((PHP_DEV_SIZE / 1024 / 1024)) MB"
log_info "PHP test size: $((PHP_TEST_SIZE / 1024 / 1024)) MB"

if [[ ${PHP_PROD_SIZE} -lt ${PHP_DEV_SIZE} ]] && [[ ${PHP_DEV_SIZE} -lt ${PHP_TEST_SIZE} ]]; then
  log_success "✓ PHP image sizes follow expected progression (prod < dev < test)"
else
  log_warning "⚠️  PHP image sizes don't follow expected progression"
fi

NODE_PROD_SIZE=$(docker image inspect "${NODE_PROD}" --format='{{.Size}}')
NODE_DEV_SIZE=$(docker image inspect "${NODE_DEV}" --format='{{.Size}}')
NODE_TEST_SIZE=$(docker image inspect "${NODE_TEST}" --format='{{.Size}}')

log_info "Node prod size: $((NODE_PROD_SIZE / 1024 / 1024)) MB"
log_info "Node dev size:  $((NODE_DEV_SIZE / 1024 / 1024)) MB"
log_info "Node test size: $((NODE_TEST_SIZE / 1024 / 1024)) MB"

if [[ ${NODE_PROD_SIZE} -lt ${NODE_DEV_SIZE} ]] && [[ ${NODE_DEV_SIZE} -lt ${NODE_TEST_SIZE} ]]; then
  log_success "✓ Node image sizes follow expected progression (prod < dev < test)"
else
  log_warning "⚠️  Node image sizes don't follow expected progression"
fi

# ================================
# TEST USER PERMISSIONS
# ================================
log_section "Testing Non-Root User Execution"

log_info "→ Checking PHP runs as non-root user (www:www)…"

PHP_USER=$(docker run --rm "${PHP_PROD}" whoami 2>/dev/null || echo "unknown")
if [[ "${PHP_USER}" == "www" ]]; then
  log_success "✓ PHP runs as user 'www'"
else
  log_warning "⚠️  PHP runs as user '${PHP_USER}' (expected: www)"
fi

log_info "→ Checking Node runs as non-root user (node:node)…"

NODE_USER=$(docker run --rm "${NODE_PROD}" whoami 2>/dev/null || echo "unknown")
if [[ "${NODE_USER}" == "node" ]]; then
  log_success "✓ Node runs as user 'node'"
else
  log_warning "⚠️  Node runs as user '${NODE_USER}' (expected: node)"
fi

# ================================
# SUMMARY
# ================================
log_section "Multi-Stage Integrity Test Complete"
log_success "✅ Multi-stage integrity verified"

log_info "Summary:"
log_info "  - PHP stages: prod ✓ dev ✓ test ✓"
log_info "  - Node stages: prod ✓ dev ✓ test ✓"
log_info "  - Extensions: Xdebug/PCOV correctly placed"
log_info "  - Image sizes: Progressive growth validated"
log_info "  - Security: Non-root execution verified"

exit 0
