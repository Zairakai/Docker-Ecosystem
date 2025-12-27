#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
WORKDIR="${WORKDIR:-/var/www/html}"
TEST_RESULTS_DIR="${TEST_RESULTS_DIR:-/tmp/test-results}"
COVERAGE_DIR="${COVERAGE_DIR:-/tmp/coverage-reports}"
LOG_DIR="${LOG_DIR:-/var/log/testing}"

# Test configuration
RUN_UNIT_TESTS="${RUN_UNIT_TESTS:-true}"
RUN_FEATURE_TESTS="${RUN_FEATURE_TESTS:-true}"
RUN_INTEGRATION_TESTS="${RUN_INTEGRATION_TESTS:-true}"
RUN_COVERAGE="${RUN_COVERAGE:-true}"
RUN_STATIC_ANALYSIS="${RUN_STATIC_ANALYSIS:-true}"
RUN_CODE_QUALITY="${RUN_CODE_QUALITY:-true}"

# Logging functions
log() {
  echo -e "${BLUE}[TEST-RUNNER]${NC} $1"
}

error() {
  echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warn() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Setup test environment
setup_test_environment() {
  log "Setting up test environment…"

  # Create necessary directories
  mkdir -p "$TEST_RESULTS_DIR" "$COVERAGE_DIR" "$LOG_DIR"
  chown -R www:www "$TEST_RESULTS_DIR" "$COVERAGE_DIR" "$LOG_DIR"

  # Change to working directory
  if [ -d "$WORKDIR" ]; then
    cd "$WORKDIR"
    log "Changed to working directory: $WORKDIR"
  else
    error "Working directory does not exist: $WORKDIR"
    exit 1
  fi

  # Clean previous test results
  if [ -n "$TEST_RESULTS_DIR" ] && [ "$TEST_RESULTS_DIR" != "/" ]; then
    rm -rf "${TEST_RESULTS_DIR:?}"/* 2>/dev/null || true
  fi
  if [ -n "$COVERAGE_DIR" ] && [ "$COVERAGE_DIR" != "/" ]; then
    rm -rf "${COVERAGE_DIR:?}"/* 2>/dev/null || true
  fi

  success "Test environment setup completed"
}

# Run PHPUnit tests
run_phpunit_tests() {
  log "Running PHPUnit tests…"

  local phpunit_cmd="phpunit"
  local phpunit_args=""

  # Configure PHPUnit
  if [ -f "phpunit.xml" ] || [ -f "phpunit.xml.dist" ]; then
    log "Found PHPUnit configuration file"
  else
    warn "No PHPUnit configuration found, using defaults"
    phpunit_args="$phpunit_args --bootstrap vendor/autoload.php tests/"
  fi

  # Add coverage if enabled
  if [ "$RUN_COVERAGE" = "true" ]; then
    phpunit_args="$phpunit_args --coverage-html $COVERAGE_DIR/html"
    phpunit_args="$phpunit_args --coverage-clover $COVERAGE_DIR/clover.xml"
    phpunit_args="$phpunit_args --coverage-xml $COVERAGE_DIR/xml"
    log "Coverage reporting enabled"
  fi

  # Add test output formatting
  phpunit_args="$phpunit_args --log-junit $TEST_RESULTS_DIR/phpunit.xml"
  phpunit_args="$phpunit_args --testdox-html $TEST_RESULTS_DIR/testdox.html"

  # Filter tests by type if specified
  if [ "$RUN_UNIT_TESTS" = "true" ] && [ "$RUN_FEATURE_TESTS" = "false" ]; then
      phpunit_args="$phpunit_args --group unit"
  elif [ "$RUN_FEATURE_TESTS" = "true" ] && [ "$RUN_UNIT_TESTS" = "false" ]; then
      phpunit_args="$phpunit_args --group feature"
  fi

  # Run PHPUnit
  log "Executing: $phpunit_cmd $phpunit_args"
  if $phpunit_cmd $phpunit_args; then
    success "PHPUnit tests passed"
    return 0
  else
    error "PHPUnit tests failed"
    return 1
  fi
}

# Run Pest tests (if available)
run_pest_tests() {
  if [ -f "vendor/bin/pest" ]; then
    log "Running Pest tests…"

    local pest_args=""

    # Add coverage if enabled
    if [ "$RUN_COVERAGE" = "true" ]; then
      pest_args="$pest_args --coverage --coverage-html $COVERAGE_DIR/pest-html"
    fi

    # Add parallel execution if supported
    pest_args="$pest_args --parallel"

    # Run Pest
    if vendor/bin/pest $pest_args; then
      success "Pest tests passed"
      return 0
    else
      error "Pest tests failed"
      return 1
    fi
  else
    log "Pest not found, skipping Pest tests"
    return 0
  fi
}

# Run static analysis
run_static_analysis() {
  if [ "$RUN_STATIC_ANALYSIS" != "true" ]; then
    log "Static analysis disabled, skipping"
    return 0
  fi

  log "Running static analysis…"

  local analysis_failed=0

  # Run PHPStan
  if command -v phpstan >/dev/null 2>&1; then
    log "Running PHPStan…"
    if phpstan analyse --no-progress --error-format=junit > "$TEST_RESULTS_DIR/phpstan.xml" 2>&1; then
      success "PHPStan analysis passed"
    else
      error "PHPStan analysis failed"
      analysis_failed=1
    fi
  else
    warn "PHPStan not available"
  fi

  # Run Psalm
  if command -v psalm >/dev/null 2>&1; then
    log "Running Psalm…"
    if psalm --output-format=junit > "$TEST_RESULTS_DIR/psalm.xml" 2>&1; then
      success "Psalm analysis passed"
    else
      error "Psalm analysis failed"
      analysis_failed=1
    fi
  else
    warn "Psalm not available"
  fi

  return $analysis_failed
}

# Run code quality checks
run_code_quality() {
  if [ "$RUN_CODE_QUALITY" != "true" ]; then
    log "Code quality checks disabled, skipping"
    return 0
  fi

  log "Running code quality checks…"

  local quality_failed=0

  # Run PHP CS Fixer (dry run)
  if command -v php-cs-fixer >/dev/null 2>&1; then
    log "Running PHP CS Fixer (dry run)…"
    if php-cs-fixer fix --dry-run --format=junit > "$TEST_RESULTS_DIR/php-cs-fixer.xml" 2>&1; then
      success "PHP CS Fixer check passed"
    else
      warn "PHP CS Fixer found formatting issues"
    fi
  else
    warn "PHP CS Fixer not available"
  fi

  # Run PHP_CodeSniffer
  if command -v phpcs >/dev/null 2>&1; then
    log "Running PHP_CodeSniffer…"
    if phpcs --report=junit --report-file="$TEST_RESULTS_DIR/phpcs.xml" . 2>/dev/null; then
      success "PHP_CodeSniffer check passed"
    else
      warn "PHP_CodeSniffer found coding standard violations"
    fi
  else
    warn "PHP_CodeSniffer not available"
  fi

  # Run PHPCPD (Copy/Paste Detector)
  if command -v phpcpd >/dev/null 2>&1; then
    log "Running PHP Copy/Paste Detector…"
    if phpcpd --log-pmd "$TEST_RESULTS_DIR/phpcpd.xml" . 2>/dev/null; then
      success "PHPCPD check passed"
    else
      warn "PHPCPD found duplicate code"
    fi
  else
    warn "PHPCPD not available"
  fi

  # Run PHPMD (Mess Detector)
  if command -v phpmd >/dev/null 2>&1; then
    log "Running PHP Mess Detector…"
    if phpmd . xml cleancode,codesize,controversial,design,naming,unusedcode --reportfile "$TEST_RESULTS_DIR/phpmd.xml" 2>/dev/null; then
      success "PHPMD check passed"
    else
      warn "PHPMD found potential issues"
    fi
  else
    warn "PHPMD not available"
  fi

  return $quality_failed
}

# Generate test summary
generate_summary() {
  log "Generating test summary…"

  local summary_file="$TEST_RESULTS_DIR/summary.txt"
  local html_summary="$TEST_RESULTS_DIR/summary.html"

  # Create text summary
  {
    echo "Test Run Summary"
    echo "================"
    echo "Date: $(date)"
    echo "PHP Version: $(php -r 'echo PHP_VERSION;')"
    echo "Working Directory: $WORKDIR"
    echo ""
    echo "Configuration:"
    echo "- Unit Tests: $RUN_UNIT_TESTS"
    echo "- Feature Tests: $RUN_FEATURE_TESTS"
    echo "- Integration Tests: $RUN_INTEGRATION_TESTS"
    echo "- Coverage: $RUN_COVERAGE"
    echo "- Static Analysis: $RUN_STATIC_ANALYSIS"
    echo "- Code Quality: $RUN_CODE_QUALITY"
    echo ""
    echo "Results:"
    find "$TEST_RESULTS_DIR" -name "*.xml" -exec basename {} \; | sed 's/^/- /'
  } > "$summary_file"

  # Create HTML summary if results exist
  if [ -f "$TEST_RESULTS_DIR/phpunit.xml" ]; then
    {
      echo "<html><head><title>Test Results Summary</title></head><body>"
      echo "<h1>Test Results Summary</h1>"
      echo "<p>Generated: $(date)</p>"
      echo "<h2>PHPUnit Results</h2>"
      echo "<a href='testdox.html'>Test Documentation</a><br>"
      if [ "$RUN_COVERAGE" = "true" ] && [ -d "$COVERAGE_DIR/html" ]; then
        echo "<a href='../coverage-reports/html/index.html'>Coverage Report</a><br>"
      fi
      echo "</body></html>"
    } > "$html_summary"
  fi

  success "Test summary generated: $summary_file"
}

# Main test runner function
main() {
  log "Starting comprehensive test run…"

  local overall_exit_code=0

  # Setup
  setup_test_environment

  # Wait for services if script exists
  if [ -f "/usr/local/bin/wait-for-services.sh" ]; then
    log "Waiting for required services…"
    /usr/local/bin/wait-for-services.sh
  fi

  # Install dependencies if needed
  if [ -f "composer.json" ] && [ ! -d "vendor" ]; then
    log "Installing dependencies…"
    composer install --no-interaction --prefer-dist
  fi

  # Run tests
  if ! run_phpunit_tests; then
    overall_exit_code=1
  fi

  if ! run_pest_tests; then
    overall_exit_code=1
  fi

  if ! run_static_analysis; then
    overall_exit_code=1
  fi

  if ! run_code_quality; then
    # Code quality issues are warnings, not failures
    true
  fi

  # Generate summary
  generate_summary

  # Final result
  if [ $overall_exit_code -eq 0 ]; then
    success "All tests completed successfully"
  else
    error "Some tests failed"
  fi

  exit $overall_exit_code
}

# Handle script arguments
case "$1" in
  --help| h)
    echo "Usage: $0 [options]"
    echo ""
    echo "Environment variables:"
    echo "  WORKDIR                Working directory (default: /var/www/html)"
    echo "  TEST_RESULTS_DIR       Test results directory (default: /tmp/test-results)"
    echo "  COVERAGE_DIR          Coverage reports directory (default: /tmp/coverage-reports)"
    echo "  RUN_UNIT_TESTS        Run unit tests (default: true)"
    echo "  RUN_FEATURE_TESTS     Run feature tests (default: true)"
    echo "  RUN_INTEGRATION_TESTS Run integration tests (default: true)"
    echo "  RUN_COVERAGE          Generate coverage reports (default: true)"
    echo "  RUN_STATIC_ANALYSIS   Run static analysis (default: true)"
    echo "  RUN_CODE_QUALITY      Run code quality checks (default: true)"
    exit 0
    ;;
  *)
    main "$@"
    ;;
esac
