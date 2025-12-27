#!/bin/bash
set -euo pipefail

# Comprehensive test runner script
# Runs all types of tests with proper reporting and error handling

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Configuration
# shellcheck disable=SC2034
readonly TIMEOUT=1800 # 30 minutes
# shellcheck disable=SC2034
readonly PARALLEL_JOBS=4

# Global variables
EXIT_CODE=0
TESTS_PASSED=0
TESTS_TOTAL=0
START_TIME=$(date +%s)

# Logging functions
log_info() {
  echo -e "${GREEN}[TEST-RUNNER]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warn() {
  echo -e "${YELLOW}[TEST-RUNNER]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

log_error() {
  echo -e "${RED}[TEST-RUNNER]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

log_step() {
  echo -e "${BLUE}[TEST-RUNNER]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Utility functions
increment_test() {
  TESTS_TOTAL=$((TESTS_TOTAL + 1))
}

pass_test() {
  TESTS_PASSED=$((TESTS_PASSED + 1))
  log_info "✓ $1"
}

fail_test() {
  EXIT_CODE=1
  log_error "✗ $1"
}

# Environment setup
setup_test_environment() {
  log_step "Setting up test environment…"

  # Create test directories
  mkdir -p test-results coverage reports

  # Set environment variables
  export NODE_ENV=test
  export CI=true
  export FORCE_COLOR=1

  # Start Xvfb for browser tests
  if command -v Xvfb >/dev/null 2>&1; then
    export DISPLAY=:99
    Xvfb :99 -screen 0 1920x1080x24 >/dev/null 2>&1 &
    XVFB_PID=$!
    sleep 2
    log_info "Started Xvfb on display :99"
  fi

  log_info "Test environment setup completed"
}

# Cleanup function
cleanup() {
  log_step "Cleaning up test environment…"

  # Kill Xvfb if it was started
  if [ -n "${XVFB_PID:-}" ]; then
    kill $XVFB_PID 2>/dev/null || true
    log_info "Stopped Xvfb"
  fi

  # Generate final report
  generate_final_report
}

trap cleanup EXIT

# Test execution functions
run_unit_tests() {
  log_step "Running unit tests…"
  increment_test

  if [ -f "package.json" ] && npm run test:unit >/dev/null 2>&1; then
    pass_test "Unit tests completed successfully"
    return 0
  elif command -v jest >/dev/null 2>&1; then
    if jest --testPathPattern="test|spec" --testPathIgnorePatterns="e2e|integration" --coverage --coverageDirectory=coverage/unit; then
      pass_test "Unit tests (Jest) completed successfully"
      return 0
    else
      fail_test "Unit tests (Jest) failed"
      return 1
    fi
  else
    log_warn "No unit test configuration found, skipping"
    return 0
  fi
}

run_integration_tests() {
  log_step "Running integration tests…"
  increment_test

  if [ -f "package.json" ] && npm run test:integration >/dev/null 2>&1; then
    pass_test "Integration tests completed successfully"
    return 0
  elif [ -d "tests/integration" ] || [ -d "test/integration" ]; then
    if jest --testPathPattern="integration" --coverage --coverageDirectory=coverage/integration; then
      pass_test "Integration tests completed successfully"
      return 0
    else
      fail_test "Integration tests failed"
      return 1
    fi
  else
    log_warn "No integration tests found, skipping"
    return 0
  fi
}

run_e2e_tests() {
  log_step "Running end-to-end tests…"
  increment_test

  if [ -f "package.json" ] && npm run test:e2e >/dev/null 2>&1; then
    pass_test "E2E tests completed successfully"
    return 0
  elif [ -d "cypress" ] && command -v cypress >/dev/null 2>&1; then
    if cypress run --headless --browser chromium --reporter json --reporter-options "output=test-results/cypress.json"; then
      pass_test "E2E tests (Cypress) completed successfully"
      return 0
    else
      fail_test "E2E tests (Cypress) failed"
      return 1
    fi
  elif command -v playwright >/dev/null 2>&1; then
    if npx playwright test --reporter=json --output-dir=test-results; then
      pass_test "E2E tests (Playwright) completed successfully"
      return 0
    else
      fail_test "E2E tests (Playwright) failed"
      return 1
    fi
  else
    log_warn "No E2E test configuration found, skipping"
    return 0
  fi
}

run_linting() {
  log_step "Running code linting…"
  increment_test

  if [ -f "package.json" ] && npm run lint >/dev/null 2>&1; then
    if npm run lint; then
      pass_test "Linting completed successfully"
      return 0
    else
      fail_test "Linting failed"
      return 1
    fi
  elif command -v eslint >/dev/null 2>&1; then
    if eslint . --ext .js,.jsx,.ts,.tsx --format json --output-file test-results/eslint.json; then
      pass_test "Linting (ESLint) completed successfully"
      return 0
    else
      fail_test "Linting (ESLint) failed"
      return 1
    fi
  else
    log_warn "No linting configuration found, skipping"
    return 0
  fi
}

run_type_checking() {
  log_step "Running type checking…"
  increment_test

  if [ -f "tsconfig.json" ] && command -v tsc >/dev/null 2>&1; then
    if tsc --noEmit; then
      pass_test "Type checking completed successfully"
      return 0
    else
      fail_test "Type checking failed"
      return 1
    fi
  else
    log_warn "No TypeScript configuration found, skipping"
    return 0
  fi
}

run_security_audit() {
  log_step "Running security audit…"
  increment_test

  if [ -f "package.json" ]; then
    if npm audit --audit-level=moderate --json > test-results/npm-audit.json; then
      pass_test "Security audit completed successfully"
      return 0
    else
      log_warn "Security audit found issues (check test-results/npm-audit.json)"
      return 0 # Don't fail the entire test suite for audit issues
    fi
  else
    log_warn "No package.json found, skipping security audit"
    return 0
  fi
}

run_performance_tests() {
  log_step "Running performance tests…"
  increment_test

  if [ -f "package.json" ] && npm run test:performance >/dev/null 2>&1; then
    if npm run test:performance; then
      pass_test "Performance tests completed successfully"
      return 0
    else
      fail_test "Performance tests failed"
      return 1
    fi
  elif [ -f "lighthouse.config.js" ] && command -v lighthouse >/dev/null 2>&1; then
    if lighthouse http://localhost:3000 --config-path=lighthouse.config.js --output=json --output-path=test-results/lighthouse.json; then
      pass_test "Performance tests (Lighthouse) completed successfully"
      return 0
    else
      fail_test "Performance tests (Lighthouse) failed"
      return 1
    fi
  else
    log_warn "No performance test configuration found, skipping"
    return 0
  fi
}

# Report generation
generate_coverage_report() {
  log_step "Generating coverage report…"

  if [ -d "coverage" ]; then
    # Merge coverage reports if multiple exist
    if command -v nyc >/dev/null 2>&1; then
      nyc merge coverage coverage/merged.json 2>/dev/null || true
      nyc report --reporter=html --reporter=lcov --temp-dir=coverage --report-dir=coverage/merged 2>/dev/null || true
    fi

    log_info "Coverage report generated in coverage/ directory"
  fi
}

generate_test_report() {
  log_step "Generating test report…"

  cat > test-results/summary.json << EOF
{
  "timestamp": "$(date -Iseconds)",
  "duration": $(($(date +%s) - START_TIME)),
  "tests": {
  "total": $TESTS_TOTAL,
  "passed": $TESTS_PASSED,
  "failed": $((TESTS_TOTAL - TESTS_PASSED))
  },
  "success": $([ $EXIT_CODE -eq 0 ] && echo "true" || echo "false")
}
EOF

  log_info "Test summary generated in test-results/summary.json"
}

generate_final_report() {
  log_step "Generating final test report…"

  local end_time
  end_time=$(date +%s)
  local duration
  duration=$((end_time - START_TIME))

  echo "
===============================================
      TEST EXECUTION SUMMARY
===============================================
Start Time:  $(date -d @$START_TIME '+%Y-%m-%d %H:%M:%S')
End Time:    $(date -d @$end_time '+%Y-%m-%d %H:%M:%S')
Duration:    ${duration}s
Tests Total:   $TESTS_TOTAL
Tests Passed:  $TESTS_PASSED
Tests Failed:  $((TESTS_TOTAL - TESTS_PASSED))
Success Rate:  $([ $TESTS_TOTAL -gt 0 ] && echo "scale=1; $TESTS_PASSED * 100 / $TESTS_TOTAL" | bc || echo "0")%
Overall:     $([ $EXIT_CODE -eq 0 ] && echo "SUCCESS" || echo "FAILURE")
===============================================
"

  generate_coverage_report
  generate_test_report
}

# Main test execution
run_test_suite() {
  local suite="$1"
  local parallel="${2:-false}"

  case "$suite" in
    "unit")
      run_unit_tests
      ;;
    "integration")
      run_integration_tests
      ;;
    "e2e")
      run_e2e_tests
      ;;
    "lint")
      run_linting
      ;;
    "type")
      run_type_checking
      ;;
    "security")
      run_security_audit
      ;;
    "performance")
      run_performance_tests
      ;;
    "all")
      if [ "$parallel" = "true" ]; then
        # Run tests in parallel
        (run_unit_tests) &
        (run_integration_tests) &
        (run_linting) &
        (run_type_checking) &
        wait

        # Run sequential tests that require specific setup
        run_e2e_tests
        run_security_audit
        run_performance_tests
      else
        # Run tests sequentially
        run_unit_tests
        run_integration_tests
        run_linting
        run_type_checking
        run_e2e_tests
        run_security_audit
        run_performance_tests
      fi
      ;;
    *)
      log_error "Unknown test suite: $suite"
      echo "Available test suites: unit, integration, e2e, lint, type, security, performance, all"
      exit 1
      ;;
  esac
}

# Help function
show_help() {
  echo "Test Runner Script"
  echo "Usage: $0 [suite] [options]"
  echo ""
  echo "Test Suites:"
  echo "  unit      - Run unit tests"
  echo "  integration   - Run integration tests"
  echo "  e2e       - Run end-to-end tests"
  echo "  lint      - Run code linting"
  echo "  type      - Run type checking"
  echo "  security    - Run security audit"
  echo "  performance   - Run performance tests"
  echo "  all       - Run all test suites (default)"
  echo ""
  echo "Options:"
  echo "  --parallel  - Run tests in parallel where possible"
  echo "  --help    - Show this help message"
  echo ""
  echo "Examples:"
  echo "  $0          # Run all tests"
  echo "  $0 unit        # Run only unit tests"
  echo "  $0 all --parallel  # Run all tests in parallel"
}

# Main function
main() {
  local suite="${1:-all}"
  local parallel=false

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      --parallel)
        parallel=true
        shift
        ;;
      --help| h)
        show_help
        exit 0
        ;;
      *)
        if [ -z "${suite_set:-}" ]; then
          suite="$1"
          suite_set=true
        fi
        shift
        ;;
    esac
  done

  log_info "Starting test execution…"
  log_info "Test suite: $suite"
  log_info "Parallel execution: $parallel"
  log_info "Working directory: $(pwd)"
  log_info "Node.js version: $(node --version 2>/dev/null || echo 'unknown')"

  # Setup environment
  setup_test_environment

  # Run tests with timeout
  if timeout $TIMEOUT bash -c "run_test_suite '$suite' '$parallel'"; then
    log_info "Test execution completed within timeout"
  else
    log_error "Test execution timed out after ${TIMEOUT}s"
    EXIT_CODE=1
  fi

  # Final summary
  if [ $EXIT_CODE -eq 0 ]; then
    log_info "All tests completed successfully"
  else
    log_error "Some tests failed"
  fi

  exit $EXIT_CODE
}

# Execute main function
main "$@"
