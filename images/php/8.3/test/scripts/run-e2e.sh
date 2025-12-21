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
E2E_RESULTS_DIR="${E2E_RESULTS_DIR:-/tmp/test-results/e2e}"
BASE_URL="${BASE_URL:-http://localhost:8000}"
BROWSER="${BROWSER:-chrome}"
HEADLESS="${HEADLESS:-true}"

# Logging functions
log() {
  echo -e "${BLUE}[E2E]${NC} $1"
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

# Setup E2E test environment
setup_e2e_environment() {
  log "Setting up E2E test environment…"

  # Create E2E results directory
  mkdir -p "$E2E_RESULTS_DIR"
  chown -R www:www "$E2E_RESULTS_DIR"

  # Change to working directory
  if [ -d "$WORKDIR" ]; then
    cd "$WORKDIR"
    log "Changed to working directory: $WORKDIR"
  else
    error "Working directory does not exist: $WORKDIR"
    exit 1
  fi

  # Clean previous E2E results
  if [ -n "$E2E_RESULTS_DIR" ] && [ "$E2E_RESULTS_DIR" != "/" ]; then
    rm -rf "${E2E_RESULTS_DIR:?}"/* 2>/dev/null || true
  fi

  success "E2E test environment setup completed"
}

# Check browser availability
check_browser_availability() {
  log "Checking browser availability…"

  case "$BROWSER" in
    "chrome"|"chromium")
      if command -v chromium-browser >/dev/null 2>&1; then
        export CHROME_BIN
        CHROME_BIN=$(which chromium-browser)
        success "Chrome/Chromium browser found: $CHROME_BIN"
      else
        error "Chrome/Chromium browser not found"
        exit 1
      fi

      if command -v chromedriver >/dev/null 2>&1; then
        export CHROMEDRIVER_PATH
        CHROMEDRIVER_PATH=$(which chromedriver)
        success "ChromeDriver found: $CHROMEDRIVER_PATH"
      else
        warn "ChromeDriver not found, using system default"
      fi
      ;;
    "firefox")
      if command -v firefox >/dev/null 2>&1; then
        export FIREFOX_BIN
        FIREFOX_BIN=$(which firefox)
        success "Firefox browser found: $FIREFOX_BIN"
      else
        error "Firefox browser not found"
        exit 1
      fi
      ;;
    *)
      error "Unsupported browser: $BROWSER"
      exit 1
      ;;
  esac
}

# Wait for application to be ready
wait_for_application() {
  log "Waiting for application to be ready at $BASE_URL…"

  local max_attempts=30
  local attempt=1

  while [ $attempt -le $max_attempts ]; do
    if curl -s --max-time 5 "$BASE_URL" >/dev/null 2>&1; then
      success "Application is ready"
      return 0
    fi

    log "Attempt $attempt/$max_attempts: Application not ready, waiting…"
    sleep 2
    attempt=$((attempt + 1))
  done

  error "Application did not become ready within the timeout period"
  return 1
}

# Run Python/Selenium E2E tests
run_selenium_tests() {
  log "Running Selenium E2E tests…"

  # Check if Python E2E tests exist
  local test_dirs=("tests/e2e" "tests/selenium" "e2e" "selenium")
  local test_dir=""

  for dir in "${test_dirs[@]}"; do
    if [ -d "$dir" ]; then
      test_dir="$dir"
      break
    fi
  done

  if [ -z "$test_dir" ]; then
    warn "No Python E2E test directory found, skipping Selenium tests"
    return 0
  fi

  log "Found E2E test directory: $test_dir"

  # Setup Selenium environment
  export SELENIUM_BASE_URL="$BASE_URL"
  export SELENIUM_BROWSER="$BROWSER"
  export SELENIUM_HEADLESS="$HEADLESS"
  export SELENIUM_IMPLICIT_WAIT="10"
  export SELENIUM_PAGE_LOAD_TIMEOUT="30"

  # Browser-specific setup
  case "$BROWSER" in
    "chrome"|"chromium")
      export SELENIUM_CHROME_OPTIONS="--no-sandbox,--disable-dev-shm-usage,--disable-gpu"
      if [ "$HEADLESS" = "true" ]; then
        export SELENIUM_CHROME_OPTIONS="$SELENIUM_CHROME_OPTIONS,--headless"
      fi
      ;;
    "firefox")
      if [ "$HEADLESS" = "true" ]; then
        export SELENIUM_FIREFOX_OPTIONS="--headless"
      fi
      ;;
  esac

  # Run pytest with Selenium tests
  local pytest_args=(
    "--verbose"
    "--tb=short"
    "--html=$E2E_RESULTS_DIR/report.html"
    "--self-contained-html"
    "--junit-xml=$E2E_RESULTS_DIR/junit.xml"
    "$test_dir"
  )

  log "Running: python3 -m pytest ${pytest_args[*]}"
  if python3 -m pytest "${pytest_args[@]}"; then
    success "Selenium E2E tests passed"
    return 0
  else
    error "Selenium E2E tests failed"
    return 1
  fi
}

# Run PHPUnit browser tests (if using Laravel Dusk or similar)
run_phpunit_browser_tests() {
  log "Looking for PHPUnit browser tests…"

  # Check for Laravel Dusk tests
  if [ -d "tests/Browser" ]; then
    log "Found Laravel Dusk browser tests"

    # Setup Dusk environment
    export DUSK_BASE_URL="$BASE_URL"
    export DUSK_HEADLESS="$HEADLESS"

    case "$BROWSER" in
      "chrome"|"chromium")
        export DUSK_DRIVER_CLASS="Laravel\Dusk\Chrome\ChromeProcess"
        ;;
      "firefox")
        export DUSK_DRIVER_CLASS="Laravel\Dusk\Firefox\FirefoxProcess"
        ;;
    esac

    # Run Dusk tests
    local dusk_args=(
      "--group=browser"
      "--log-junit=$E2E_RESULTS_DIR/dusk.xml"
    )

    if php artisan dusk "${dusk_args[@]}"; then
      success "Laravel Dusk tests passed"
      return 0
    else
      error "Laravel Dusk tests failed"
      return 1
    fi
  else
    log "No Laravel Dusk tests found"
    return 0
  fi
}

# Run JavaScript E2E tests (if using Cypress, Playwright, etc.)
run_javascript_e2e_tests() {
  log "Looking for JavaScript E2E tests…"

  # Check for Cypress
  if [ -f "cypress.config.js" ] || [ -f "cypress.json" ]; then
    log "Found Cypress configuration"

    if command -v npx >/dev/null 2>&1; then
      local cypress_args=(
        "--headless"
        "--browser $BROWSER"
        "--config baseUrl=$BASE_URL"
        "--reporter junit"
        "--reporter-options mochaFile=$E2E_RESULTS_DIR/cypress.xml"
      )

      if npx cypress run "${cypress_args[@]}"; then
        success "Cypress E2E tests passed"
        return 0
      else
        error "Cypress E2E tests failed"
        return 1
      fi
    else
      warn "npm/npx not available, skipping Cypress tests"
    fi
  fi

  # Check for Playwright
  if [ -f "playwright.config.js" ]; then
    log "Found Playwright configuration"

    if command -v npx >/dev/null 2>&1; then
      local playwright_args=(
        "--browser=$BROWSER"
        "--headed=$([ "$HEADLESS" = "false" ] && echo "true" || echo "false")"
        "--reporter=junit"
        "--output-dir=$E2E_RESULTS_DIR"
      )

      if npx playwright test "${playwright_args[@]}"; then
        success "Playwright E2E tests passed"
        return 0
      else
        error "Playwright E2E tests failed"
        return 1
      fi
    else
      warn "npm/npx not available, skipping Playwright tests"
    fi
  fi

  log "No JavaScript E2E framework found"
  return 0
}

# Take screenshots for debugging
take_debug_screenshots() {
  if [ "$HEADLESS" = "false" ]; then
    log "Headless mode disabled, skipping debug screenshots"
    return 0
  fi

  log "Taking debug screenshots…"

  # Create screenshots directory
  mkdir -p "$E2E_RESULTS_DIR/screenshots"

  # Take screenshot of the main page
  python3 << EOF
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
import os

try:
  options = Options()
  options.add_argument('--headless')
  options.add_argument('--no-sandbox')
  options.add_argument('--disable-dev-shm-usage')
  options.add_argument('--disable-gpu')
  options.add_argument('--window-size=1920,1080')

  driver = webdriver.Chrome(options=options)
  driver.get('$BASE_URL')

  screenshot_path = '$E2E_RESULTS_DIR/screenshots/homepage.png'
  driver.save_screenshot(screenshot_path)
  print(f'Screenshot saved: {screenshot_path}')

  driver.quit()
except Exception as e:
  print(f'Failed to take screenshot: {e}')
EOF

  success "Debug screenshots completed"
}

# Generate E2E test summary
generate_e2e_summary() {
  log "Generating E2E test summary…"

  local summary_file="$E2E_RESULTS_DIR/summary.txt"

  {
    echo "E2E Test Run Summary"
    echo "==================="
    echo "Date: $(date)"
    echo "Base URL: $BASE_URL"
    echo "Browser: $BROWSER"
    echo "Headless: $HEADLESS"
    echo ""
    echo "Results:"
    find "$E2E_RESULTS_DIR" -name "*.xml" -o -name "*.html" | sed 's|'"$E2E_RESULTS_DIR"'/||' | sed 's/^/- /'
    echo ""
    echo "Screenshots:"
    find "$E2E_RESULTS_DIR/screenshots" -name "*.png" 2>/dev/null | sed 's|'"$E2E_RESULTS_DIR"'/||' | sed 's/^/- /' || echo "- None"
  } > "$summary_file"

  success "E2E test summary generated: $summary_file"
}

# Main E2E test runner function
main() {
  log "Starting E2E test run…"

  local exit_code=0

  # Setup
  setup_e2e_environment
  check_browser_availability

  # Wait for application
  if ! wait_for_application; then
    error "Application not ready, cannot run E2E tests"
    exit 1
  fi

  # Run different types of E2E tests
  if ! run_selenium_tests; then
    exit_code=1
  fi

  if ! run_phpunit_browser_tests; then
    exit_code=1
  fi

  if ! run_javascript_e2e_tests; then
    # JavaScript E2E tests are optional
    true
  fi

  # Take debug screenshots
  take_debug_screenshots

  # Generate summary
  generate_e2e_summary

  # Final result
  if [ $exit_code -eq 0 ]; then
    success "E2E tests completed successfully"
  else
    error "Some E2E tests failed"
  fi

  exit $exit_code
}

# Handle script arguments
case "$1" in
  --help|-h)
    echo "Usage: $0 [options]"
    echo ""
    echo "Environment variables:"
    echo "  WORKDIR           Working directory (default: /var/www/html)"
    echo "  E2E_RESULTS_DIR   E2E results directory (default: /tmp/test-results/e2e)"
    echo "  BASE_URL          Application base URL (default: http://localhost:8000)"
    echo "  BROWSER           Browser to use: chrome|firefox (default: chrome)"
    echo "  HEADLESS          Run in headless mode (default: true)"
    exit 0
    ;;
  *)
    main "$@"
    ;;
esac
