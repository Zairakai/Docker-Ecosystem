#!/usr/bin/env bash
# scripts/pipeline/validate-shellcheck.sh
# Runs ShellCheck validation on all shell scripts
#
# Usage:
#   validate-shellcheck.sh
#
# Environment Variables:
#   SHELLCHECK_SEVERITY - Severity level (default: warning)
#   SHELLCHECK_FORMAT   - Output format (default: gcc)

set -euo pipefail

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck source=scripts/common.sh
source "${SCRIPT_DIR}/../common.sh"

log_section "Running ShellCheck Validation"

# Change to project root
cd "${PROJECT_ROOT}"

# Configuration
SEVERITY="${SHELLCHECK_SEVERITY:-warning}"
FORMAT="${SHELLCHECK_FORMAT:-gcc}"

log_info "Severity: ${SEVERITY}"
log_info "Format: ${FORMAT}"

# Check if shellcheck is available
if ! command_exists shellcheck; then
  log_error "ShellCheck not found. Please install shellcheck."
  log_info "  Alpine: apk add shellcheck"
  log_info "  Debian/Ubuntu: apt-get install shellcheck"
  log_info "  macOS: brew install shellcheck"
  exit 1
fi

SHELLCHECK_VERSION=$(shellcheck --version | grep "version:" | awk '{print $2}')
log_info "ShellCheck version: ${SHELLCHECK_VERSION}"

# Find all shell scripts (excluding vendor/third-party directories)
log_info "→ Finding shell scripts…"

# Exclusions: node_modules, vendor, .git, dist, build, coverage
mapfile -t SHELL_SCRIPTS < <(find . -name "*.sh" -type f \
  -not -path "*/node_modules/*" \
  -not -path "*/vendor/*" \
  -not -path "*/.git/*" \
  -not -path "*/dist/*" \
  -not -path "*/build/*" \
  -not -path "*/coverage/*" \
  | sort)

SCRIPT_COUNT=${#SHELL_SCRIPTS[@]}
log_info "Found ${SCRIPT_COUNT} shell scripts (excluding node_modules, vendor, .git, dist, build, coverage)"

# Display first few scripts found
if [[ ${SCRIPT_COUNT} -gt 0 ]]; then
  log_debug "Sample scripts found:"
  for i in "${!SHELL_SCRIPTS[@]}"; do
    if [[ $i -lt 5 ]]; then
      log_debug "  - ${SHELL_SCRIPTS[$i]}"
    fi
  done
  if [[ ${SCRIPT_COUNT} -gt 5 ]]; then
    log_debug "  ... and $((SCRIPT_COUNT - 5)) more"
  fi
fi

if [[ ${SCRIPT_COUNT} -eq 0 ]]; then
  log_warning "No shell scripts found"
  exit 0
fi

# Run shellcheck on all scripts
log_info "→ Running ShellCheck validation…"

FAILED=0
TOTAL=0

for script in "${SHELL_SCRIPTS[@]}"; do
  TOTAL=$((TOTAL + 1))
  log_debug "Checking: ${script}"

  if shellcheck --severity="${SEVERITY}" --format="${FORMAT}" "${script}"; then
    log_debug "  ✓ ${script}"
  else
    log_error "  ✗ ${script} - ShellCheck failed"
    FAILED=$((FAILED + 1))
  fi
done

# Summary
log_section "ShellCheck Validation Summary"

if [[ ${FAILED} -eq 0 ]]; then
  log_success "✅ All ${TOTAL} shell scripts passed ShellCheck validation"
  log_info ""
  log_info "Coverage:"
  log_info "  • Project scripts: scripts/**/*.sh"
  log_info "  • Pipeline scripts: scripts/pipeline/*.sh"
  log_info "  • Image scripts: images/**/scripts/*.sh"
  log_info "  • Backup scripts: scripts/backup/*.sh"
  log_info ""
  log_info "Severity level: ${SEVERITY}"
  log_info "Format: ${FORMAT}"
  exit 0
else
  log_error "❌ ${FAILED}/${TOTAL} scripts failed ShellCheck validation"
  log_error ""
  log_error "Failed scripts must be fixed before committing."
  log_error "Run 'shellcheck <script>' to see specific issues."
  exit 1
fi
