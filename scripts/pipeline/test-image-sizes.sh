#!/usr/bin/env bash
# scripts/pipeline/test-image-sizes.sh
# Pulls all Docker images and generates size report
#
# Usage:
#   test-image-sizes.sh
#
# Environment Variables:
#   CI_REGISTRY_IMAGE   - Registry image prefix (required)
#   IMAGE_SUFFIX        - Image tag suffix (default: -local)
#   CI_PIPELINE_ID      - Pipeline ID for reporting (optional)
#   CI_COMMIT_SHORT_SHA - Commit SHA for reporting (optional)
#   CI_COMMIT_TAG       - Git tag for reporting (optional)
#   OUTPUT_FILE         - Output file path (default: image-sizes.txt)

set -euo pipefail

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck source=scripts/common.sh
source "${SCRIPT_DIR}/../common.sh"

# Validate required environment variables
require_env "CI_REGISTRY_IMAGE"

# Configuration
IMAGE_SUFFIX="${IMAGE_SUFFIX:--local}"
OUTPUT_FILE="${OUTPUT_FILE:-${PROJECT_ROOT}/image-sizes.txt}"
CI_PIPELINE_ID="${CI_PIPELINE_ID:-N/A}"
CI_COMMIT_SHORT_SHA="${CI_COMMIT_SHORT_SHA:-local}"
CI_COMMIT_TAG="${CI_COMMIT_TAG:-N/A}"

log_section "Tracking Docker Image Sizes"

log_info "Registry: ${CI_REGISTRY_IMAGE}"
log_info "Suffix: ${IMAGE_SUFFIX}"
log_info "Pipeline: ${CI_PIPELINE_ID}"
log_info "Commit: ${CI_COMMIT_SHORT_SHA}"
log_info "Tag: ${CI_COMMIT_TAG}"

# ================================
# DEFINE IMAGES TO TEST
# ================================
IMAGES=(
  # PHP Stack
  "${CI_REGISTRY_IMAGE}/php:8.3${IMAGE_SUFFIX}-prod"
  "${CI_REGISTRY_IMAGE}/php:8.3${IMAGE_SUFFIX}-dev"
  "${CI_REGISTRY_IMAGE}/php:8.3${IMAGE_SUFFIX}-test"

  # Node Stack
  "${CI_REGISTRY_IMAGE}/node:20${IMAGE_SUFFIX}-prod"
  "${CI_REGISTRY_IMAGE}/node:20${IMAGE_SUFFIX}-dev"
  "${CI_REGISTRY_IMAGE}/node:20${IMAGE_SUFFIX}-test"

  # Database Services
  "${CI_REGISTRY_IMAGE}/database:mysql-8.0${IMAGE_SUFFIX}"
  "${CI_REGISTRY_IMAGE}/database:redis-7${IMAGE_SUFFIX}"

  # Web Services
  "${CI_REGISTRY_IMAGE}/web:nginx-1.26${IMAGE_SUFFIX}"

  # Application Services
  "${CI_REGISTRY_IMAGE}/services:mailhog${IMAGE_SUFFIX}"
  "${CI_REGISTRY_IMAGE}/services:minio${IMAGE_SUFFIX}"
  "${CI_REGISTRY_IMAGE}/services:e2e-testing${IMAGE_SUFFIX}"
  "${CI_REGISTRY_IMAGE}/services:performance-testing${IMAGE_SUFFIX}"
)

# ================================
# VERIFY LOCAL IMAGES
# ================================
log_info "→ Verifying local images (built on runner)…"

MISSING_IMAGES=0

for image in "${IMAGES[@]}"; do
  log_info "Checking: ${image}"

  if docker image inspect "${image}" &>/dev/null; then
    log_success "  ✓ Found locally"
  else
    log_error "  ✗ Not found locally: ${image}"
    MISSING_IMAGES=$((MISSING_IMAGES + 1))
  fi
done

if [[ ${MISSING_IMAGES} -gt 0 ]]; then
  log_error "${MISSING_IMAGES} images not found locally"
  log_error "Make sure all build jobs completed successfully on the same runner"
  exit 1
fi

log_success "All ${#IMAGES[@]} images found locally"

# ================================
# GENERATE SIZE REPORT
# ================================
log_info "→ Generating size report…"

cat > "${OUTPUT_FILE}" <<EOF
========================================
ZAIRAKAI DOCKER ECOSYSTEM - IMAGE SIZES
========================================
Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
Pipeline: ${CI_PIPELINE_ID}
Commit: ${CI_COMMIT_SHORT_SHA}
Tag: ${CI_COMMIT_TAG}
========================================

EOF

# Get image sizes (filter by commit SHA if not local)
if [[ "${CI_COMMIT_SHORT_SHA}" != "local" ]]; then
  docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" \
    | grep "${CI_COMMIT_SHORT_SHA}" \
    >> "${OUTPUT_FILE}"
else
  docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" \
    | grep "${IMAGE_SUFFIX#-}" \
    >> "${OUTPUT_FILE}"
fi

echo "" >> "${OUTPUT_FILE}"
echo "========================================" >> "${OUTPUT_FILE}"

# Count total images
if [[ "${CI_COMMIT_SHORT_SHA}" != "local" ]]; then
  TOTAL_IMAGES=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep "${CI_COMMIT_SHORT_SHA}" | wc -l)
else
  TOTAL_IMAGES=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep "${IMAGE_SUFFIX#-}" | wc -l)
fi

echo "TOTAL IMAGES: ${TOTAL_IMAGES}" >> "${OUTPUT_FILE}"
echo "========================================" >> "${OUTPUT_FILE}"

# ================================
# DISPLAY REPORT
# ================================
log_section "Image Size Report"
cat "${OUTPUT_FILE}"

log_success "Report generated: ${OUTPUT_FILE}"

# ================================
# SIZE VALIDATION (OPTIONAL)
# ================================
log_info "→ Validating image sizes…"

# Check if production images are reasonably sized
PHP_PROD_SIZE=$(docker image inspect "${CI_REGISTRY_IMAGE}/php:8.3${IMAGE_SUFFIX}-prod" --format='{{.Size}}')
NODE_PROD_SIZE=$(docker image inspect "${CI_REGISTRY_IMAGE}/node:20${IMAGE_SUFFIX}-prod" --format='{{.Size}}')

PHP_PROD_MB=$((PHP_PROD_SIZE / 1024 / 1024))
NODE_PROD_MB=$((NODE_PROD_SIZE / 1024 / 1024))

log_info "PHP prod size: ${PHP_PROD_MB} MB"
log_info "Node prod size: ${NODE_PROD_MB} MB"

# Warn if images are unexpectedly large (> 100MB for prod)
if [[ ${PHP_PROD_MB} -gt 100 ]]; then
  log_warning "PHP prod image is larger than expected: ${PHP_PROD_MB} MB (threshold: 100 MB)"
fi

if [[ ${NODE_PROD_MB} -gt 100 ]]; then
  log_warning "Node prod image is larger than expected: ${NODE_PROD_MB} MB (threshold: 100 MB)"
fi

log_section "Image Size Test Complete"
log_success "✅ All ${#IMAGES[@]} images tested successfully"

exit 0
