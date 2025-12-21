#!/bin/bash
set -e

echo "📦 Installing PHP dependencies…"

# Simple Composer installation
if [ -f "composer.json" ]; then
  echo "Installing Composer dependencies…"

  # Choose install mode based on environment
  if [ "${APP_ENV:-dev}" = "production" ]; then
    echo "Production mode - installing without dev dependencies"
    composer install --no-dev --optimize-autoloader --no-interaction
  else
    echo "Development mode - installing all dependencies"
    composer install --no-interaction
  fi

  echo "✅ PHP dependencies installed"
else
  echo "⚠️ No composer.json found"
fi
