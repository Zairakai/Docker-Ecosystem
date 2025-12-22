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

# Find all shell scripts
log_info "→ Finding shell scripts…"

mapfile -t SHELL_SCRIPTS < <(find . -name "*.sh" -type f)

SCRIPT_COUNT=${#SHELL_SCRIPTS[@]}
log_info "Found ${SCRIPT_COUNT} shell scripts"

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
  log_success "✅ All ${TOTAL} scripts passed ShellCheck validation"
  exit 0
else
  log_error "❌ ${FAILED}/${TOTAL} scripts failed ShellCheck validation"
  exit 1
fi
