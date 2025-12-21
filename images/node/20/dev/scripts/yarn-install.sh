#!/bin/bash
set -e

echo "📦 Installing dependencies…"

# Simple installation with fallback
if [ -f "package.json" ]; then
  # Try yarn first, fallback to npm
  if command -v yarn >/dev/null 2>&1; then
    echo "Using yarn…"
    yarn install || npm install
  else
    echo "Using npm…"
    npm install
  fi
  echo "✅ Dependencies installed"
else
  echo "⚠️ No package.json found"
fi
