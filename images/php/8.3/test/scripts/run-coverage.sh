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
COVERAGE_DIR="${COVERAGE_DIR:-/tmp/coverage-reports}"
COVERAGE_ENGINE="${COVERAGE_ENGINE:-pcov}"
COVERAGE_MIN_THRESHOLD="${COVERAGE_MIN_THRESHOLD:-80}"

# Logging functions
log() {
  echo -e "${BLUE}[COVERAGE]${NC} $1"
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

# Setup coverage environment
setup_coverage_environment() {
  log "Setting up coverage environment…"

  # Create coverage directory
  mkdir -p "$COVERAGE_DIR"
  chown -R www:www "$COVERAGE_DIR"

  # Change to working directory
  if [ -d "$WORKDIR" ]; then
    cd "$WORKDIR"
    log "Changed to working directory: $WORKDIR"
  else
    error "Working directory does not exist: $WORKDIR"
    exit 1
  fi

  # Clean previous coverage reports
  if [ -n "$COVERAGE_DIR" ] && [ "$COVERAGE_DIR" != "/" ]; then
    rm -rf "${COVERAGE_DIR:?}"/* 2>/dev/null || true
  fi

  success "Coverage environment setup completed"
}

# Configure coverage engine
configure_coverage_engine() {
  log "Configuring coverage engine: $COVERAGE_ENGINE"

  case "$COVERAGE_ENGINE" in
    "pcov")
      # Enable PCOV and disable Xdebug for better performance
      if php -m | grep -q "pcov"; then
        php -d pcov.enabled=1 -d xdebug.mode=off -r "echo 'PCOV enabled for coverage collection';" >/dev/null
        success "PCOV coverage engine configured"
      else
        error "PCOV extension not available"
        exit 1
      fi
      ;;
    "xdebug")
      # Enable Xdebug coverage mode and disable PCOV
      if php -m | grep -q "xdebug"; then
        php -d xdebug.mode=coverage -d pcov.enabled=0 -r "echo 'Xdebug enabled for coverage collection';" >/dev/null
        success "Xdebug coverage engine configured"
      else
        error "Xdebug extension not available"
        exit 1
      fi
      ;;
    *)
      error "Unknown coverage engine: $COVERAGE_ENGINE"
      exit 1
      ;;
  esac
}

# Run coverage with PHPUnit
run_phpunit_coverage() {
  log "Running PHPUnit with coverage collection…"

  local phpunit_cmd="phpunit"
  local coverage_args=""

  # Configure coverage engine
  case "$COVERAGE_ENGINE" in
    "pcov")
      coverage_args="-d pcov.enabled=1 -d xdebug.mode=off"
      ;;
    "xdebug")
      coverage_args="-d xdebug.mode=coverage -d pcov.enabled=0"
      ;;
  esac

  # Coverage output formats
  local coverage_formats=(
    "--coverage-html $COVERAGE_DIR/html"
    "--coverage-clover $COVERAGE_DIR/clover.xml"
    "--coverage-xml $COVERAGE_DIR/xml"
    "--coverage-text $COVERAGE_DIR/coverage.txt"
    "--coverage-php $COVERAGE_DIR/coverage.php"
  )

  # Build command
  local full_cmd="php $coverage_args $phpunit_cmd ${coverage_formats[*]}"

  log "Executing: $full_cmd"
  if eval $full_cmd; then
    success "PHPUnit coverage collection completed"
    return 0
  else
    error "PHPUnit coverage collection failed"
    return 1
  fi
}

# Run coverage with Pest
run_pest_coverage() {
  if [ -f "vendor/bin/pest" ]; then
    log "Running Pest with coverage collection…"

    local pest_args=""
    case "$COVERAGE_ENGINE" in
      "pcov")
        pest_args="-d pcov.enabled=1 -d xdebug.mode=off"
        ;;
      "xdebug")
        pest_args="-d xdebug.mode=coverage -d pcov.enabled=0"
        ;;
    esac

    local pest_cmd="php $pest_args vendor/bin/pest"
    pest_cmd="$pest_cmd --coverage --coverage-html $COVERAGE_DIR/pest-html"
    pest_cmd="$pest_cmd --coverage-clover $COVERAGE_DIR/pest-clover.xml"

    log "Executing: $pest_cmd"
    if eval $pest_cmd; then
      success "Pest coverage collection completed"
      return 0
    else
      error "Pest coverage collection failed"
      return 1
    fi
  else
    log "Pest not found, skipping Pest coverage"
    return 0
  fi
}

# Generate coverage badges
generate_coverage_badges() {
  log "Generating coverage badges…"

  local clover_file="$COVERAGE_DIR/clover.xml"
  local badge_file="$COVERAGE_DIR/badge.svg"

  if [ -f "$clover_file" ]; then
    # Extract coverage percentage from clover.xml
    local coverage_percent
    coverage_percent=$(php -r "
      \$xml = simplexml_load_file('$clover_file');
      \$metrics = \$xml->project->metrics;
      \$covered = (int)\$metrics['coveredstatements'];
      \$total = (int)\$metrics['statements'];
      if (\$total > 0) {
          echo round((\$covered / \$total) * 100, 2);
      } else {
          echo '0';
      }
    " 2>/dev/null || echo "unknown")

    log "Overall coverage: ${coverage_percent}%"

    # Generate simple SVG badge
    local color="red"
    if [ "$coverage_percent" != "unknown" ]; then
      if (( $(echo "$coverage_percent >= 90" | bc -l) )); then
        color="brightgreen"
      elif (( $(echo "$coverage_percent >= 80" | bc -l) )); then
        color="yellow"
      elif (( $(echo "$coverage_percent >= 70" | bc -l) )); then
        color="orange"
      fi
    fi

    # Create badge SVG
    cat > "$badge_file" << EOF
<svg xmlns="http://www.w3.org/2000/svg" width="104" height="20">
<linearGradient id="b" x2="0" y2="100%">
<stop offset="0" stop-color="#bbb" stop-opacity=".1"/>
<stop offset="1" stop-opacity=".1"/>
</linearGradient>
<mask id="a">
<rect width="104" height="20" rx="3" fill="#fff"/>
</mask>
<g mask="url(#a)">
<path fill="#555" d="M0 0h63v20H0z"/>
<path fill="$color" d="M63 0h41v20H63z"/>
<path fill="url(#b)" d="M0 0h104v20H0z"/>
</g>
<g fill="#fff" text-anchor="middle" font-family="DejaVu Sans,Verdana,Geneva,sans-serif" font-size="11">
<text x="31.5" y="15" fill="#010101" fill-opacity=".3">coverage</text>
<text x="31.5" y="14">coverage</text>
<text x="82.5" y="15" fill="#010101" fill-opacity=".3">${coverage_percent}%</text>
<text x="82.5" y="14">${coverage_percent}%</text>
</g>
</svg>
EOF

    success "Coverage badge generated: $badge_file"
  else
    warn "No clover.xml file found, skipping badge generation"
  fi
}

# Check coverage thresholds
check_coverage_thresholds() {
  log "Checking coverage thresholds…"

  local clover_file="$COVERAGE_DIR/clover.xml"

  if [ -f "$clover_file" ]; then
    local coverage_percent
    coverage_percent=$(php -r "
      \$xml = simplexml_load_file('$clover_file');
      \$metrics = \$xml->project->metrics;
      \$covered = (int)\$metrics['coveredstatements'];
      \$total = (int)\$metrics['statements'];
      if (\$total > 0) {
        echo round((\$covered / \$total) * 100, 2);
      } else {
        echo '0';
      }
    " 2>/dev/null || echo "0")

    log "Coverage percentage: ${coverage_percent}%"
    log "Minimum threshold: ${COVERAGE_MIN_THRESHOLD}%"

    if (( $(echo "$coverage_percent >= $COVERAGE_MIN_THRESHOLD" | bc -l) )); then
      success "Coverage threshold met: ${coverage_percent}% >= ${COVERAGE_MIN_THRESHOLD}%"
      return 0
    else
      error "Coverage threshold not met: ${coverage_percent}% < ${COVERAGE_MIN_THRESHOLD}%"
      return 1
    fi
  else
    error "No coverage data found"
    return 1
  fi
}

# Generate coverage summary
generate_coverage_summary() {
  log "Generating coverage summary…"

  local summary_file="$COVERAGE_DIR/summary.txt"
  local clover_file="$COVERAGE_DIR/clover.xml"

  {
    echo "Coverage Report Summary"
    echo "======================"
    echo "Date: $(date)"
    echo "Coverage Engine: $COVERAGE_ENGINE"
    echo "Minimum Threshold: ${COVERAGE_MIN_THRESHOLD}%"
    echo ""

    if [ -f "$clover_file" ]; then
      echo "Coverage Statistics:"
      php -r "
        \$xml = simplexml_load_file('$clover_file');
        \$metrics = \$xml->project->metrics;
        echo 'Lines: ' . \$metrics['coveredstatements'] . '/' . \$metrics['statements'] . PHP_EOL;
        echo 'Methods: ' . \$metrics['coveredmethods'] . '/' . \$metrics['methods'] . PHP_EOL;
        echo 'Classes: ' . \$metrics['coveredclasses'] . '/' . \$metrics['classes'] . PHP_EOL;
        \$covered = (int)\$metrics['coveredstatements'];
        \$total = (int)\$metrics['statements'];
        if (\$total > 0) {
          echo 'Percentage: ' . round((\$covered / \$total) * 100, 2) . '%' . PHP_EOL;
        }
      " 2>/dev/null
    else
      echo "No coverage data available"
    fi

    echo ""
    echo "Generated Files:"
    find "$COVERAGE_DIR" -type f -name "*" | sed 's|'"$COVERAGE_DIR"'/||' | sed 's/^/- /'
  } > "$summary_file"

  success "Coverage summary generated: $summary_file"
}

# Main coverage runner function
main() {
  log "Starting coverage collection…"

  local exit_code=0

  # Setup
  setup_coverage_environment
  configure_coverage_engine

  # Install dependencies if needed
  if [ -f "composer.json" ] && [ ! -d "vendor" ]; then
    log "Installing dependencies…"
    composer install --no-interaction --prefer-dist
  fi

  # Run coverage collection
  if ! run_phpunit_coverage; then
    exit_code=1
  fi

  if ! run_pest_coverage; then
    # Pest coverage is optional, don't fail
    true
  fi

  # Generate reports and check thresholds
  generate_coverage_badges
  generate_coverage_summary

  if ! check_coverage_thresholds; then
    exit_code=1
  fi

  # Final result
  if [ $exit_code -eq 0 ]; then
    success "Coverage collection completed successfully"
  else
    error "Coverage collection failed or thresholds not met"
  fi

  exit $exit_code
}

# Handle script arguments
case "$1" in
  --help| h)
    echo "Usage: $0 [options]"
    echo ""
    echo "Environment variables:"
    echo "  WORKDIR                Working directory (default: /var/www/html)"
    echo "  COVERAGE_DIR          Coverage output directory (default: /tmp/coverage-reports)"
    echo "  COVERAGE_ENGINE       Coverage engine: pcov|xdebug (default: pcov)"
    echo "  COVERAGE_MIN_THRESHOLD Minimum coverage percentage (default: 80)"
    exit 0
    ;;
  *)
    main "$@"
    ;;
esac
