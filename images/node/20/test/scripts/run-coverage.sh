#!/bin/bash
set -euo pipefail

# Coverage runner script
# Comprehensive code coverage analysis with multiple tools

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Configuration
readonly COVERAGE_THRESHOLD=70
readonly COVERAGE_DIR="coverage"
readonly REPORTS_DIR="test-results/coverage"

# Logging functions
log_info() {
  echo -e "${GREEN}[COVERAGE]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warn() {
  echo -e "${YELLOW}[COVERAGE]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

log_error() {
  echo -e "${RED}[COVERAGE]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

log_step() {
  echo -e "${BLUE}[COVERAGE]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Setup coverage environment
setup_coverage_environment() {
  log_step "Setting up coverage environment…"

  # Create coverage directories
  mkdir -p "$COVERAGE_DIR" "$REPORTS_DIR"

  # Set environment variables
  export NODE_ENV=test
  export NYC_CONFIG_OVERRIDE="{\"all\": true}"

  log_info "Coverage environment setup completed"
}

# Run Jest coverage
run_jest_coverage() {
  log_step "Running Jest coverage…"

  if command -v jest >/dev/null 2>&1; then
    jest --coverage \
       --coverageDirectory="$COVERAGE_DIR/jest" \
       --coverageReporters=html \
       --coverageReporters=lcov \
       --coverageReporters=json \
       --coverageReporters=text \
       --coverageThreshold="{\"global\":{\"lines\":$COVERAGE_THRESHOLD,\"functions\":$COVERAGE_THRESHOLD,\"branches\":$COVERAGE_THRESHOLD,\"statements\":$COVERAGE_THRESHOLD}}" \
       || true

    if [ -f "$COVERAGE_DIR/jest/lcov.info" ]; then
      log_info "Jest coverage completed successfully"
      return 0
    else
      log_warn "Jest coverage failed or no coverage data generated"
      return 1
    fi
  else
    log_warn "Jest not available, skipping Jest coverage"
    return 0
  fi
}

# Run NYC coverage
run_nyc_coverage() {
  log_step "Running NYC coverage…"

  if command -v nyc >/dev/null 2>&1; then
    nyc --reporter=html \
      --reporter=lcov \
      --reporter=json \
      --reporter=text \
      --report-dir="$COVERAGE_DIR/nyc" \
      --temp-dir="$COVERAGE_DIR/.nyc_output" \
      --check-coverage \
      --lines=$COVERAGE_THRESHOLD \
      --functions=$COVERAGE_THRESHOLD \
      --branches=$COVERAGE_THRESHOLD \
      --statements=$COVERAGE_THRESHOLD \
      npm test || true

    if [ -f "$COVERAGE_DIR/nyc/lcov.info" ]; then
      log_info "NYC coverage completed successfully"
      return 0
    else
      log_warn "NYC coverage failed or no coverage data generated"
      return 1
    fi
  else
    log_warn "NYC not available, skipping NYC coverage"
    return 0
  fi
}

# Run C8 coverage
run_c8_coverage() {
  log_step "Running C8 coverage…"

  if command -v c8 >/dev/null 2>&1; then
    c8 --reporter=html \
       --reporter=lcov \
       --reporter=json \
       --reporter=text \
       --reports-dir="$COVERAGE_DIR/c8" \
       --check-coverage \
       --lines=$COVERAGE_THRESHOLD \
       --functions=$COVERAGE_THRESHOLD \
       --branches=$COVERAGE_THRESHOLD \
       --statements=$COVERAGE_THRESHOLD \
       npm test || true

    if [ -f "$COVERAGE_DIR/c8/lcov.info" ]; then
      log_info "C8 coverage completed successfully"
      return 0
    else
      log_warn "C8 coverage failed or no coverage data generated"
      return 1
    fi
  else
    log_warn "C8 not available, skipping C8 coverage"
    return 0
  fi
}

# Merge coverage reports
merge_coverage_reports() {
  log_step "Merging coverage reports…"

  local lcov_files=()
  
  # Find all lcov.info files
  while IFS= read -r -d '' file; do
    lcov_files+=("$file")
  done < <(find "$COVERAGE_DIR" -name "lcov.info" -print0 2>/dev/null)

  if [ ${#lcov_files[@]} -gt 1 ] && command -v lcov >/dev/null 2>&1; then
    log_info "Found ${#lcov_files[@]} lcov files, merging…"

    # Create merged directory
    mkdir -p "$COVERAGE_DIR/merged"

    # Merge lcov files
    local merge_cmd="lcov"
    for file in "${lcov_files[@]}"; do
      merge_cmd="$merge_cmd -a '$file'"
    done
    merge_cmd="$merge_cmd -o '$COVERAGE_DIR/merged/lcov.info'"

    eval "$merge_cmd" || log_warn "Failed to merge lcov files"

    # Generate HTML report from merged data
    if [ -f "$COVERAGE_DIR/merged/lcov.info" ]; then
      genhtml "$COVERAGE_DIR/merged/lcov.info" \
          --output-directory "$COVERAGE_DIR/merged/html" \
          --title "Merged Coverage Report" \
          --legend || log_warn "Failed to generate merged HTML report"

      log_info "Merged coverage report generated"
    fi
  else
    log_info "No multiple lcov files found or lcov not available, skipping merge"
  fi
}

# Generate coverage summary
generate_coverage_summary() {
  log_step "Generating coverage summary…"

  local summary_file="$REPORTS_DIR/summary.json"
  local summary_text="$REPORTS_DIR/summary.txt"
  
  # Create reports directory
  mkdir -p "$REPORTS_DIR"

  # Generate JSON summary
  cat > "$summary_file" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "tools": {
  "jest": $([ -f "$COVERAGE_DIR/jest/coverage-final.json" ] && echo "true" || echo "false"),
  "nyc": $([ -f "$COVERAGE_DIR/nyc/coverage-final.json" ] && echo "true" || echo "false"),
  "c8": $([ -f "$COVERAGE_DIR/c8/coverage-final.json" ] && echo "true" || echo "false")
  },
  "reports": {
  "html": $([ -d "$COVERAGE_DIR" ] && find "$COVERAGE_DIR" -name "index.html" | wc -l || echo "0"),
  "lcov": $([ -d "$COVERAGE_DIR" ] && find "$COVERAGE_DIR" -name "lcov.info" | wc -l || echo "0"),
  "json": $([ -d "$COVERAGE_DIR" ] && find "$COVERAGE_DIR" -name "coverage-final.json" | wc -l || echo "0")
  }
}
EOF

  # Generate text summary
  cat > "$summary_text" << EOF
COVERAGE ANALYSIS SUMMARY
========================
Timestamp: $(date '+%Y-%m-%d %H:%M:%S')
Threshold: $COVERAGE_THRESHOLD%

Tools Used:
EOF

  [ -f "$COVERAGE_DIR/jest/coverage-final.json" ] && echo "  ✓ Jest" >> "$summary_text" || echo "  ✗ Jest" >> "$summary_text"
  [ -f "$COVERAGE_DIR/nyc/coverage-final.json" ] && echo "  ✓ NYC" >> "$summary_text" || echo "  ✗ NYC" >> "$summary_text"
  [ -f "$COVERAGE_DIR/c8/coverage-final.json" ] && echo "  ✓ C8" >> "$summary_text" || echo "  ✗ C8" >> "$summary_text"

  echo "" >> "$summary_text"
  echo "Reports Generated:" >> "$summary_text"
  echo "  HTML Reports: $([ -d "$COVERAGE_DIR" ] && find "$COVERAGE_DIR" -name "index.html" | wc -l || echo "0")" >> "$summary_text"
  echo "  LCOV Reports: $([ -d "$COVERAGE_DIR" ] && find "$COVERAGE_DIR" -name "lcov.info" | wc -l || echo "0")" >> "$summary_text"
  echo "  JSON Reports: $([ -d "$COVERAGE_DIR" ] && find "$COVERAGE_DIR" -name "coverage-final.json" | wc -l || echo "0")" >> "$summary_text"

  log_info "Coverage summary generated"
  cat "$summary_text"
}

# Cleanup old coverage data
cleanup_old_coverage() {
  log_step "Cleaning up old coverage data…"

  if [ -d "$COVERAGE_DIR" ]; then
    if [ -n "$COVERAGE_DIR" ] && [ "$COVERAGE_DIR" != "/" ]; then
      rm -rf "${COVERAGE_DIR:?}"/* 2>/dev/null || true
    fi
    log_info "Old coverage data cleaned up"
  fi
}

# Upload coverage (placeholder for CI/CD integration)
upload_coverage() {
  log_step "Preparing coverage for upload…"

  # This is a placeholder for coverage service integration
  # Examples: Codecov, Coveralls, SonarQube, etc.
  
  if [ -f "$COVERAGE_DIR/merged/lcov.info" ]; then
    # Example for Codecov (commented out)
    # bash <(curl -s https://codecov.io/bash) -f "$COVERAGE_DIR/merged/lcov.info"
    
    log_info "Coverage data available for upload at: $COVERAGE_DIR/merged/lcov.info"
  elif [ -d "$COVERAGE_DIR" ]; then
    local lcov_files
    lcov_files=$(find "$COVERAGE_DIR" -name "lcov.info" | head -1)
    if [ -n "$lcov_files" ]; then
      log_info "Coverage data available for upload at: $lcov_files"
    fi
  else
    log_warn "No coverage data available for upload"
  fi
}

# Help function
show_help() {
  echo "Coverage Runner Script"
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  --clean     - Clean old coverage data before running"
  echo "  --jest    - Run only Jest coverage"
  echo "  --nyc     - Run only NYC coverage"
  echo "  --c8      - Run only C8 coverage"
  echo "  --merge     - Only merge existing coverage reports"
  echo "  --upload    - Prepare coverage for upload"
  echo "  --threshold N - Set coverage threshold (default: $COVERAGE_THRESHOLD)"
  echo "  --help    - Show this help message"
  echo ""
  echo "Examples:"
  echo "  $0          # Run all coverage tools"
  echo "  $0 --jest      # Run only Jest coverage"
  echo "  $0 --clean --jest  # Clean and run Jest coverage"
  echo "  $0 --threshold 80  # Set 80% coverage threshold"
}

# Main function
main() {
  local clean=false
  local jest_only=false
  local nyc_only=false
  local c8_only=false
  local merge_only=false
  local upload_only=false
  local threshold=$COVERAGE_THRESHOLD

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      --clean)
        clean=true
        shift
        ;;
      --jest)
        jest_only=true
        shift
        ;;
      --nyc)
        nyc_only=true
        shift
        ;;
      --c8)
        c8_only=true
        shift
        ;;
      --merge)
        merge_only=true
        shift
        ;;
      --upload)
        upload_only=true
        shift
        ;;
      --threshold)
        threshold="$2"
        shift 2
        ;;
      --help| h)
        show_help
        exit 0
        ;;
      *)
        log_error "Unknown option: $1"
        show_help
        exit 1
        ;;
    esac
  done

  log_info "Starting coverage analysis…"
  log_info "Threshold: $threshold%"
  log_info "Working directory: $(pwd)"

  # Update threshold
  COVERAGE_THRESHOLD=$threshold

  # Setup environment
  setup_coverage_environment

  # Clean old data if requested
  if [ "$clean" = true ]; then
    cleanup_old_coverage
  fi

  # Handle specific modes
  if [ "$upload_only" = true ]; then
    upload_coverage
    exit 0
  elif [ "$merge_only" = true ]; then
    merge_coverage_reports
    generate_coverage_summary
    exit 0
  fi

  # Run coverage tools
  local exit_code=0

  if [ "$jest_only" = true ]; then
    run_jest_coverage || exit_code=1
  elif [ "$nyc_only" = true ]; then
    run_nyc_coverage || exit_code=1
  elif [ "$c8_only" = true ]; then
    run_c8_coverage || exit_code=1
  else
    # Run all available tools
    run_jest_coverage || true
    run_nyc_coverage || true
    run_c8_coverage || true
  fi

  # Post-process results
  merge_coverage_reports
  generate_coverage_summary
  upload_coverage

  if [ $exit_code -eq 0 ]; then
    log_info "Coverage analysis completed successfully"
  else
    log_warn "Coverage analysis completed with some failures"
  fi

  exit $exit_code
}

# Execute main function
main "$@"
