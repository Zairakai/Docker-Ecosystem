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
PERFORMANCE_RESULTS_DIR="${PERFORMANCE_RESULTS_DIR:-/tmp/test-results/performance}"
BASE_URL="${BASE_URL:-http://localhost:8000}"
DURATION="${DURATION:-60s}"
CONCURRENT_USERS="${CONCURRENT_USERS:-10}"

# Logging functions
log() {
  echo -e "${BLUE}[PERFORMANCE]${NC} $1"
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

# Setup performance test environment
setup_performance_environment() {
  log "Setting up performance test environment…"

  # Create performance results directory
  mkdir -p "$PERFORMANCE_RESULTS_DIR"
  chown -R www:www "$PERFORMANCE_RESULTS_DIR"

  # Change to working directory
  if [ -d "$WORKDIR" ]; then
    cd "$WORKDIR"
    log "Changed to working directory: $WORKDIR"
  else
    error "Working directory does not exist: $WORKDIR"
    exit 1
  fi

  # Clean previous performance results
  if [ -n "$PERFORMANCE_RESULTS_DIR" ] && [ "$PERFORMANCE_RESULTS_DIR" != "/" ]; then
    rm -rf "${PERFORMANCE_RESULTS_DIR:?}"/* 2>/dev/null || true
  fi

  success "Performance test environment setup completed"
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

# Run basic load testing with curl
run_curl_load_test() {
  log "Running basic load test with curl…"

  local test_urls=(
    "$BASE_URL"
    "$BASE_URL/api/health"
    "$BASE_URL/api/status"
  )

  local results_file="$PERFORMANCE_RESULTS_DIR/curl_load_test.txt"

  {
    echo "Curl Load Test Results"
    echo "====================="
    echo "Date: $(date)"
    echo "Base URL: $BASE_URL"
    echo "Concurrent Users: $CONCURRENT_USERS"
    echo "Duration: $DURATION"
    echo ""
  } > "$results_file"

  for url in "${test_urls[@]}"; do
    log "Testing URL: $url"

    {
      echo "URL: $url"
      echo "----------"
    } >> "$results_file"

    # Run multiple concurrent requests
    local pids=()
    local start_time
    start_time=$(date +%s)

    for _ in $(seq 1 "$CONCURRENT_USERS"); do
      {
        while [ $(($(date +%s) - start_time)) -lt 60 ]; do
          curl -s -w "Response time: %{time_total}s, Status: %{http_code}\n" -o /dev/null "$url" || echo "Request failed"
          sleep 1
        done
      } &
      pids+=($!)
    done

    # Wait for all background processes to complete
    for pid in "${pids[@]}"; do
      wait "$pid"
    done >> "$results_file" 2>&1

    {
      echo ""
      echo "---"
      echo ""
    } >> "$results_file"
  done

  success "Curl load test completed: $results_file"
}

# Run Apache Bench (ab) performance test
run_apache_bench_test() {
  if ! command -v ab >/dev/null 2>&1; then
    warn "Apache Bench (ab) not available, installing…"
    if command -v apk >/dev/null 2>&1; then
      apk add --no-cache apache2-utils >/dev/null 2>&1 || warn "Failed to install Apache Bench"
    fi
  fi

  if command -v ab >/dev/null 2>&1; then
    log "Running Apache Bench performance test…"

    local ab_results="$PERFORMANCE_RESULTS_DIR/apache_bench.txt"
    local requests=1000
    local concurrency=10

    log "Running ab -n $requests -c $concurrency $BASE_URL"
    if ab -n "$requests" -c "$concurrency" "$BASE_URL" > "$ab_results" 2>&1; then
      success "Apache Bench test completed: $ab_results"

      # Extract key metrics
      local rps
      local mean_time
      rps=$(grep "Requests per second" "$ab_results" | awk '{print $4}')
      mean_time=$(grep "Time per request" "$ab_results" | head -1 | awk '{print $4}')

      log "Performance metrics: ${rps} req/sec, ${mean_time}ms avg"
    else
      error "Apache Bench test failed"
    fi
  else
    warn "Apache Bench not available, skipping ab test"
  fi
}

# Run XHProf profiling
run_xhprof_profiling() {
  if php -m | grep -q "xhprof"; then
    log "Running XHProf profiling…"

    # Enable XHProf
    local xhprof_enabled
    xhprof_enabled=$(php -r "echo ini_get('xhprof.enable');")
    if [ "$xhprof_enabled" != "1" ]; then
      log "Enabling XHProf for profiling…"
    fi

    # Profile key endpoints
    local profile_urls=(
      "$BASE_URL?XHPROF_PROFILE=1"
      "$BASE_URL/api/health?XHPROF_PROFILE=1"
    )

    for url in "${profile_urls[@]}"; do
      log "Profiling URL: $url"

      # Make request with profiling enabled
      curl -s "$url" >/dev/null || warn "Failed to profile $url"
    done

    # Copy profiling data
    if [ -d "/tmp/profiling-data" ]; then
      cp -r /tmp/profiling-data/* "$PERFORMANCE_RESULTS_DIR/" 2>/dev/null || true
      success "XHProf profiling data collected"
    fi
  else
    warn "XHProf not available, skipping profiling"
  fi
}

# Run memory usage analysis
run_memory_analysis() {
  log "Running memory usage analysis…"

  local memory_log="$PERFORMANCE_RESULTS_DIR/memory_usage.txt"

  {
    echo "Memory Usage Analysis"
    echo "===================="
    echo "Date: $(date)"
    echo ""
    echo "PHP Memory Configuration:"
    echo "memory_limit: $(php -r 'echo ini_get("memory_limit");')"
    echo ""
    echo "System Memory:"
    cat /proc/meminfo | grep -E "(MemTotal|MemFree|MemAvailable|Cached|Buffers)"
    echo ""
    echo "PHP-FPM Process Memory:"
    ps aux | grep php-fpm | grep -v grep | awk '{sum += $6} END {print "Total RSS: " sum " KB"}'
    echo ""
  } > "$memory_log"

  # Test memory usage with different request sizes
  log "Testing memory usage with various request sizes…"

  for size in 1KB 10KB 100KB 1MB; do
    log "Testing with $size payload…"

    # Create test payload
    local payload_size
    case "$size" in
      "1KB") payload_size=1024 ;;
      "10KB") payload_size=10240 ;;
      "100KB") payload_size=102400 ;;
      "1MB") payload_size=1048576 ;;
    esac

    local test_data
    test_data=$(python3 -c "print('x' * $payload_size)")

    # Measure memory before and after request
    local mem_before
    mem_before=$(ps -o pid,rss -p $$ | tail -1 | awk '{print $2}')

    # Make request with payload
    echo "$test_data" | curl -s -X POST -d @- "$BASE_URL" >/dev/null 2>&1 || true

    local mem_after
    mem_after=$(ps -o pid,rss -p $$ | tail -1 | awk '{print $2}')
    local mem_diff
    mem_diff=$((mem_after - mem_before))

    echo "Payload $size: Memory change: ${mem_diff}KB" >> "$memory_log"
  done

  success "Memory analysis completed: $memory_log"
}

# Run database performance analysis
run_database_analysis() {
  log "Running database performance analysis…"

  local db_log="$PERFORMANCE_RESULTS_DIR/database_performance.txt"

  {
    echo "Database Performance Analysis"
    echo "============================"
    echo "Date: $(date)"
    echo ""
  } > "$db_log"

  # Check if this is a Laravel application
  if [ -f "artisan" ]; then
    log "Detected Laravel application, running Laravel-specific DB analysis…"

    {
      echo "Laravel Database Configuration:"
      php artisan config:show database 2>/dev/null || echo "Unable to show database config"
      echo ""

      echo "Database Query Log (if enabled):"
      # This would require enabling query logging in Laravel
      echo "Query logging needs to be enabled in the application"
      echo ""
    } >> "$db_log"
  fi

  # Generic PHP database analysis
  {
    echo "PHP Database Extensions:"
    php -m | grep -i -E "(mysql|pgsql|sqlite|redis|mongo)" || echo "No database extensions found"
    echo ""

    echo "PDO Drivers:"
    php -r "print_r(PDO::getAvailableDrivers());" 2>/dev/null || echo "PDO not available"
    echo ""
  } >> "$db_log"

  success "Database analysis completed: $db_log"
}

# Generate performance report
generate_performance_report() {
  log "Generating performance report…"

  local report_file="$PERFORMANCE_RESULTS_DIR/performance_report.html"
  local summary_file="$PERFORMANCE_RESULTS_DIR/summary.txt"

  # Generate text summary
  {
    echo "Performance Test Summary"
    echo "======================="
    echo "Date: $(date)"
    echo "Base URL: $BASE_URL"
    echo "Duration: $DURATION"
    echo "Concurrent Users: $CONCURRENT_USERS"
    echo ""
    echo "Generated Files:"
    find "$PERFORMANCE_RESULTS_DIR" -type f | sed 's|'"$PERFORMANCE_RESULTS_DIR"'/||' | sed 's/^/- /'
    echo ""
  } > "$summary_file"

  # Extract key metrics from Apache Bench if available
  if [ -f "$PERFORMANCE_RESULTS_DIR/apache_bench.txt" ]; then
    echo "Apache Bench Results:" >> "$summary_file"
    grep -E "(Requests per second|Time per request|Transfer rate)" "$PERFORMANCE_RESULTS_DIR/apache_bench.txt" | sed 's/^/  /' >> "$summary_file"
    echo "" >> "$summary_file"
  fi

  # Generate HTML report
  {
    echo "<html><head><title>Performance Test Report</title></head><body>"
    echo "<h1>Performance Test Report</h1>"
    echo "<p>Generated: $(date)</p>"
    echo "<h2>Configuration</h2>"
    echo "<ul>"
    echo "<li>Base URL: $BASE_URL</li>"
    echo "<li>Duration: $DURATION</li>"
    echo "<li>Concurrent Users: $CONCURRENT_USERS</li>"
    echo "</ul>"
    echo "<h2>Results</h2>"
    echo "<ul>"
    find "$PERFORMANCE_RESULTS_DIR" -name "*.txt" -exec basename {} \; | sed 's/^/<li><a href="/' | sed 's/$/">&<\/a><\/li>/'
    echo "</ul>"
    echo "</body></html>"
  } > "$report_file"

  success "Performance report generated: $report_file"
}

# Main performance test runner function
main() {
  log "Starting performance test run…"

  local exit_code=0

  # Setup
  setup_performance_environment

  # Wait for application
  if ! wait_for_application; then
    error "Application not ready, cannot run performance tests"
    exit 1
  fi

  # Run performance tests
  run_curl_load_test
  run_apache_bench_test
  run_xhprof_profiling
  run_memory_analysis
  run_database_analysis

  # Generate reports
  generate_performance_report

  # Final result
  success "Performance tests completed successfully"
  exit $exit_code
}

# Handle script arguments
case "$1" in
  --help| h)
    echo "Usage: $0 [options]"
    echo ""
    echo "Environment variables:"
    echo "  WORKDIR                 Working directory (default: /var/www/html)"
    echo "  PERFORMANCE_RESULTS_DIR Performance results directory (default: /tmp/test-results/performance)"
    echo "  BASE_URL               Application base URL (default: http://localhost:8000)"
    echo "  DURATION               Test duration (default: 60s)"
    echo "  CONCURRENT_USERS       Number of concurrent users (default: 10)"
    exit 0
    ;;
  *)
    main "$@"
    ;;
esac
