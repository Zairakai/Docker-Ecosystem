#!/bin/bash
set -e

# Check if required tools are available
if ! command -v node >/dev/null 2>&1; then
  echo "Node.js not available"
  exit 1
fi

if ! command -v npx >/dev/null 2>&1; then
  echo "npx not available"
  exit 1
fi

# Check if Cucumber is available
if ! npx cucumber-js --version >/dev/null 2>&1; then
  echo "Cucumber.js not available"
  exit 1
fi

# Check if Playwright is available
if ! npx playwright --version >/dev/null 2>&1; then
  echo "Playwright not available"
  exit 1
fi

# Check if browsers are available
if ! command -v chromium-browser >/dev/null 2>&1; then
  echo "Chromium browser not available"
  exit 1
fi

echo "E2E testing environment is healthy"
exit 0
