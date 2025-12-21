#!/bin/bash
set -e

echo "🎭 Starting E2E Test Runner…"

# Configuration
BROWSER=${BROWSER:-chromium}
HEADLESS=${HEADLESS:-true}
BASE_URL=${BASE_URL:-http://localhost:3000}
PARALLEL=${PARALLEL:-2}

echo "Configuration:"
echo "  Browser: $BROWSER"
echo "  Headless: $HEADLESS"
echo "  Base URL: $BASE_URL"
echo "  Parallel: $PARALLEL"

# Create report directories
mkdir -p reports screenshots

# Wait for application to be ready
echo "⏳ Waiting for application at $BASE_URL…"
timeout 60s bash -c 'until curl -f '"$BASE_URL"' >/dev/null 2>&1; do sleep 2; done' || {
  echo "❌ Application not ready at $BASE_URL"
  exit 1
}

echo "✅ Application ready"

# Check if we have feature files
if [ ! -d "features" ] || [ -z "$(find features -name '*.feature' 2>/dev/null)" ]; then
  echo "📂 No .feature files found, using examples…"
  cp -r examples/* .
fi

# Run Cucumber tests
echo "🥒 Running Cucumber tests…"
if npx cucumber-js --config cucumber.config.js; then
  echo "✅ Cucumber tests passed"
  CUCUMBER_EXIT=0
else
  echo "❌ Cucumber tests failed"
  CUCUMBER_EXIT=1
fi

# Run Playwright tests (if available)
if [ -f "playwright.config.js" ] && [ -d "tests" ]; then
  echo "🎭 Running Playwright tests…"
  if npx playwright test; then
    echo "✅ Playwright tests passed"
    PLAYWRIGHT_EXIT=0
  else
    echo "❌ Playwright tests failed"
    PLAYWRIGHT_EXIT=1
  fi
else
  echo "ℹ️  No Playwright tests found, skipping"
  PLAYWRIGHT_EXIT=0
fi

# Generate combined report
echo "📊 Generating reports…"
if command -v allure >/dev/null 2>&1; then
  allure generate reports --clean -o reports/allure-report
  echo "📈 Allure report: reports/allure-report/index.html"
fi

# Final result
if [ $CUCUMBER_EXIT -eq 0 ] && [ $PLAYWRIGHT_EXIT -eq 0 ]; then
  echo "🎉 All tests passed!"
  exit 0
else
  echo "💥 Some tests failed"
  exit 1
fi
