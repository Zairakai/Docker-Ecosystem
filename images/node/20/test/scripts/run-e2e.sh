#!/bin/bash
set -euo pipefail

# End-to-end test runner script
# Comprehensive E2E testing with multiple frameworks

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Configuration
# shellcheck disable=SC2034
readonly E2E_TIMEOUT=600 # 10 minutes
readonly RETRY_COUNT=2
readonly BROWSER_TIMEOUT=30000

# Global variables
EXIT_CODE=0
XVFB_PID=""
SERVER_PID=""

# Logging functions
log_info() {
  echo -e "${GREEN}[E2E]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warn() {
  echo -e "${YELLOW}[E2E]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

log_error() {
  echo -e "${RED}[E2E]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

log_step() {
  echo -e "${BLUE}[E2E]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Cleanup function
cleanup() {
  log_step "Cleaning up E2E environment…"

  # Stop application server
  if [ -n "$SERVER_PID" ]; then
    kill $SERVER_PID 2>/dev/null || true
    wait $SERVER_PID 2>/dev/null || true
    log_info "Stopped application server"
  fi

  # Stop Xvfb
  if [ -n "$XVFB_PID" ]; then
    kill $XVFB_PID 2>/dev/null || true
    log_info "Stopped Xvfb"
  fi
}

trap cleanup EXIT

# Setup E2E environment
setup_e2e_environment() {
  log_step "Setting up E2E environment…"

  # Create test results directory
  mkdir -p test-results/e2e screenshots videos

  # Set environment variables
  export NODE_ENV=test
  export CI=true
  export FORCE_COLOR=1
  export DISPLAY=:99
  export CYPRESS_CACHE_FOLDER="$HOME/.cache/cypress"
  export PLAYWRIGHT_BROWSERS_PATH="$HOME/.cache/playwright"

  # Start Xvfb for headless testing
  if command -v Xvfb >/dev/null 2>&1; then
    Xvfb :99 -screen 0 1920x1080x24 >/dev/null 2>&1 &
    XVFB_PID=$!
    sleep 3
    log_info "Started Xvfb on display :99"
  else
    log_warn "Xvfb not available, tests may fail in headless environment"
  fi

  log_info "E2E environment setup completed"
}

# Start application server
start_application_server() {
  local port="${1:-3000}"
  local build_first="${2:-true}"

  log_step "Starting application server on port $port…"

  # Build application if requested
  if [ "$build_first" = "true" ] && [ -f "package.json" ]; then
    if npm run build >/dev/null 2>&1; then
      log_info "Application built successfully"
    else
      log_warn "Build failed or no build script found"
    fi
  fi

  # Start server
  if [ -f "package.json" ]; then
    if npm run start:test >/dev/null 2>&1 & then
      SERVER_PID=$!
      log_info "Started test server (PID: $SERVER_PID)"
    elif npm run start >/dev/null 2>&1 & then
      SERVER_PID=$!
      log_info "Started application server (PID: $SERVER_PID)"
    else
      log_error "Failed to start application server"
      return 1
    fi
  else
    log_warn "No package.json found, assuming server is externally managed"
    return 0
  fi

  # Wait for server to be ready
  log_step "Waiting for server to be ready…"
  local max_attempts=30
  local attempt=0
  
  while [ $attempt -lt $max_attempts ]; do
    if curl -s "http://localhost:$port" >/dev/null 2>&1; then
      log_info "Server is ready at http://localhost:$port"
      return 0
    fi
    
    sleep 2
    attempt=$((attempt + 1))
  done

  log_error "Server failed to start within $(($max_attempts * 2)) seconds"
  return 1
}

# Run Cypress tests
run_cypress_tests() {
  log_step "Running Cypress E2E tests…"

  if ! command -v cypress >/dev/null 2>&1; then
    log_warn "Cypress not available, skipping Cypress tests"
    return 0
  fi

  # Check if Cypress is configured
  if [ ! -f "cypress.config.js" ] && [ ! -f "cypress.json" ] && [ ! -d "cypress" ]; then
    log_warn "No Cypress configuration found, skipping Cypress tests"
    return 0
  fi

  # Verify Cypress installation
  if ! cypress verify >/dev/null 2>&1; then
    log_error "Cypress verification failed"
    return 1
  fi

  # Run tests with retry logic
  local attempt=0
  while [ $attempt -le $RETRY_COUNT ]; do
    log_info "Cypress test attempt $((attempt + 1))/$((RETRY_COUNT + 1))"

    if cypress run \
      --headless \
      --browser chromium \
      --reporter json \
      --reporter-options "output=test-results/e2e/cypress.json" \
      --config video=false \
      --config screenshotOnRunFailure=true \
      --config screenshotsFolder=screenshots/cypress \
      --config defaultCommandTimeout=$BROWSER_TIMEOUT; then
      log_info "Cypress tests passed"
      return 0
    else
      log_warn "Cypress tests failed on attempt $((attempt + 1))"
      attempt=$((attempt + 1))
      
      if [ $attempt -le $RETRY_COUNT ]; then
        log_info "Retrying in 5 seconds…"
        sleep 5
      fi
    fi
  done

  log_error "Cypress tests failed after $((RETRY_COUNT + 1)) attempts"
  return 1
}

# Run Playwright tests
run_playwright_tests() {
  log_step "Running Playwright E2E tests…"

  if ! command -v playwright >/dev/null 2>&1; then
    log_warn "Playwright not available, skipping Playwright tests"
    return 0
  fi

  # Check if Playwright is configured
  if [ ! -f "playwright.config.js" ] && [ ! -f "playwright.config.ts" ]; then
    log_warn "No Playwright configuration found, skipping Playwright tests"
    return 0
  fi

  # Verify Playwright browsers
  if ! npx playwright --version >/dev/null 2>&1; then
    log_error "Playwright verification failed"
    return 1
  fi

  # Run tests with retry logic
  local attempt=0
  while [ $attempt -le $RETRY_COUNT ]; do
    log_info "Playwright test attempt $((attempt + 1))/$((RETRY_COUNT + 1))"

    if npx playwright test \
      --reporter=json \
      --output-dir=test-results/e2e \
      --config timeout=$BROWSER_TIMEOUT; then
      log_info "Playwright tests passed"
      return 0
    else
      log_warn "Playwright tests failed on attempt $((attempt + 1))"
      attempt=$((attempt + 1))
      
      if [ $attempt -le $RETRY_COUNT ]; then
        log_info "Retrying in 5 seconds…"
        sleep 5
      fi
    fi
  done

  log_error "Playwright tests failed after $((RETRY_COUNT + 1)) attempts"
  return 1
}

# Run Puppeteer tests
run_puppeteer_tests() {
  log_step "Running Puppeteer E2E tests…"

  if ! node -e "require('puppeteer')" 2>/dev/null; then
    log_warn "Puppeteer not available, skipping Puppeteer tests"
    return 0
  fi

  # Check for test files
  if [ ! -d "tests/e2e" ] && [ ! -d "test/e2e" ] && [ ! -d "e2e" ]; then
    log_warn "No Puppeteer test directory found, skipping Puppeteer tests"
    return 0
  fi

  # Run tests
  local test_dirs=("tests/e2e" "test/e2e" "e2e")
  local found_tests=false

  for dir in "${test_dirs[@]}"; do
    if [ -d "$dir" ]; then
      local test_files
      test_files=$(find "$dir" -name "*.test.js" -o -name "*.spec.js" 2>/dev/null || true)
      
      if [ -n "$test_files" ]; then
        found_tests=true
        log_info "Running Puppeteer tests in $dir"
        
        if jest --testPathPattern="$dir" --testTimeout=$((BROWSER_TIMEOUT * 2)); then
          log_info "Puppeteer tests in $dir passed"
        else
          log_error "Puppeteer tests in $dir failed"
          return 1
        fi
      fi
    fi
  done

  if [ "$found_tests" = false ]; then
    log_warn "No Puppeteer test files found"
    return 0
  fi

  return 0
}

# Run WebDriver tests
run_webdriver_tests() {
  log_step "Running WebDriver E2E tests…"

  if ! node -e "require('selenium-webdriver')" 2>/dev/null; then
    log_warn "Selenium WebDriver not available, skipping WebDriver tests"
    return 0
  fi

  # Check for test files
  local webdriver_dirs=("tests/webdriver" "test/webdriver" "webdriver")
  local found_tests=false

  for dir in "${webdriver_dirs[@]}"; do
    if [ -d "$dir" ]; then
      local test_files
      test_files=$(find "$dir" -name "*.test.js" -o -name "*.spec.js" 2>/dev/null || true)
      
      if [ -n "$test_files" ]; then
        found_tests=true
        log_info "Running WebDriver tests in $dir"
        
        if jest --testPathPattern="$dir" --testTimeout=$((BROWSER_TIMEOUT * 2)); then
          log_info "WebDriver tests in $dir passed"
        else
          log_error "WebDriver tests in $dir failed"
          return 1
        fi
      fi
    fi
  done

  if [ "$found_tests" = false ]; then
    log_warn "No WebDriver test files found"
    return 0
  fi

  return 0
}

# Generate E2E report
generate_e2e_report() {
  log_step "Generating E2E test report…"

  local report_file="test-results/e2e/summary.json"
  local report_text="test-results/e2e/summary.txt"
  
  mkdir -p "test-results/e2e"

  # Create JSON report
  cat > "$report_file" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "frameworks": {
  "cypress": $([ -f "test-results/e2e/cypress.json" ] && echo "true" || echo "false"),
  "playwright": $([ -f "test-results/e2e/playwright-report/index.html" ] && echo "true" || echo "false")
  },
  "artifacts": {
  "screenshots": $([ -d "screenshots" ] && find screenshots -name "*.png" | wc -l || echo "0"),
  "videos": $([ -d "videos" ] && find videos -name "*.mp4" | wc -l || echo "0")
  },
  "success": $([ $EXIT_CODE -eq 0 ] && echo "true" || echo "false")
}
EOF

  # Create text report
  cat > "$report_text" << EOF
E2E TEST EXECUTION SUMMARY
=========================
Timestamp: $(date '+%Y-%m-%d %H:%M:%S')

Frameworks:
EOF

  [ -f "test-results/e2e/cypress.json" ] && echo "  ✓ Cypress" >> "$report_text" || echo "  ✗ Cypress" >> "$report_text"
  [ -f "test-results/e2e/playwright-report/index.html" ] && echo "  ✓ Playwright" >> "$report_text" || echo "  ✗ Playwright" >> "$report_text"

  echo "" >> "$report_text"
  echo "Artifacts Generated:" >> "$report_text"
  echo "  Screenshots: $([ -d "screenshots" ] && find screenshots -name "*.png" | wc -l || echo "0")" >> "$report_text"
  echo "  Videos: $([ -d "videos" ] && find videos -name "*.mp4" | wc -l || echo "0")" >> "$report_text"

  echo "" >> "$report_text"
  echo "Overall Result: $([ $EXIT_CODE -eq 0 ] && echo "SUCCESS" || echo "FAILURE")" >> "$report_text"

  log_info "E2E report generated"
  cat "$report_text"
}

# Help function
show_help() {
  echo "E2E Test Runner Script"
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  --cypress   - Run only Cypress tests"
  echo "  --playwright  - Run only Playwright tests"
  echo "  --puppeteer   - Run only Puppeteer tests"
  echo "  --webdriver   - Run only WebDriver tests"
  echo "  --port N    - Application server port (default: 3000)"
  echo "  --no-build  - Skip building application before tests"
  echo "  --no-server   - Skip starting application server"
  echo "  --timeout N   - Browser timeout in ms (default: $BROWSER_TIMEOUT)"
  echo "  --retries N   - Number of retries (default: $RETRY_COUNT)"
  echo "  --help    - Show this help message"
  echo ""
  echo "Examples:"
  echo "  $0          # Run all E2E tests"
  echo "  $0 --cypress     # Run only Cypress tests"
  echo "  $0 --port 8080     # Use port 8080 for application server"
  echo "  $0 --no-server     # Run tests without starting server"
}

# Main function
main() {
  local cypress_only=false
  local playwright_only=false
  local puppeteer_only=false
  local webdriver_only=false
  local port=3000
  local build_first=true
  local start_server=true
  local timeout=$BROWSER_TIMEOUT
  local retries=$RETRY_COUNT

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      --cypress)
        cypress_only=true
        shift
        ;;
      --playwright)
        playwright_only=true
        shift
        ;;
      --puppeteer)
        puppeteer_only=true
        shift
        ;;
      --webdriver)
        webdriver_only=true
        shift
        ;;
      --port)
        port="$2"
        shift 2
        ;;
      --no-build)
        build_first=false
        shift
        ;;
      --no-server)
        start_server=false
        shift
        ;;
      --timeout)
        timeout="$2"
        shift 2
        ;;
      --retries)
        retries="$2"
        shift 2
        ;;
      --help|-h)
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

  log_info "Starting E2E tests…"
  log_info "Port: $port"
  log_info "Build first: $build_first"
  log_info "Start server: $start_server"
  log_info "Timeout: ${timeout}ms"
  log_info "Retries: $retries"

  # Update global variables
  BROWSER_TIMEOUT=$timeout
  RETRY_COUNT=$retries

  # Setup environment
  setup_e2e_environment

  # Start application server if needed
  if [ "$start_server" = true ]; then
    if ! start_application_server "$port" "$build_first"; then
      log_error "Failed to start application server"
      exit 1
    fi
  fi

  # Run E2E tests
  if [ "$cypress_only" = true ]; then
    run_cypress_tests || EXIT_CODE=1
  elif [ "$playwright_only" = true ]; then
    run_playwright_tests || EXIT_CODE=1
  elif [ "$puppeteer_only" = true ]; then
    run_puppeteer_tests || EXIT_CODE=1
  elif [ "$webdriver_only" = true ]; then
    run_webdriver_tests || EXIT_CODE=1
  else
    # Run all available frameworks
    run_cypress_tests || true
    run_playwright_tests || true
    run_puppeteer_tests || true
    run_webdriver_tests || true
  fi

  # Generate report
  generate_e2e_report

  if [ $EXIT_CODE -eq 0 ]; then
    log_info "E2E tests completed successfully"
  else
    log_error "E2E tests failed"
  fi

  exit $EXIT_CODE
}

# Execute main function
main "$@"
