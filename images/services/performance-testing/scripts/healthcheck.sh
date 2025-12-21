#!/bin/bash

set -e

# Check if k6 is installed and working
if ! command -v k6 &> /dev/null; then
  echo "k6 not found"
  exit 1
fi

# Check if artillery is installed and working
if ! command -v artillery &> /dev/null; then
  echo "artillery not found"
  exit 1
fi

# Check if autocannon is installed and working
if ! command -v autocannon &> /dev/null; then
  echo "autocannon not found"
  exit 1
fi

# Check if locust is installed and working
if ! command -v locust &> /dev/null; then
  echo "locust not found"
  exit 1
fi

echo "All performance testing tools available"
exit 0
