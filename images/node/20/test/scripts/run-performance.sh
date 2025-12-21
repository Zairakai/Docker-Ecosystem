#!/bin/bash
set -euo pipefail

# Performance testing script
# Comprehensive performance testing with multiple tools

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Configuration
readonly DEFAULT_DURATION="30s"
readonly DEFAULT_RATE="10/s"
readonly DEFAULT_CONNECTIONS=10
readonly RESULTS_DIR="test-results/performance"

# Global variables
EXIT_CODE=0
SERVER_PID=""

# Logging functions
log_info() {
  echo -e "${GREEN}[PERF]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warn() {
  echo -e "${YELLOW}[PERF]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

log_error() {
  echo -e "${RED}[PERF]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

log_step() {
  echo -e "${BLUE}[PERF]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Cleanup function
cleanup() {
  log_step "Cleaning up performance testing environment…"

  # Stop application server
  if [ -n "$SERVER_PID" ]; then
    kill $SERVER_PID 2>/dev/null || true
    wait $SERVER_PID 2>/dev/null || true
    log_info "Stopped application server"
  fi
}

trap cleanup EXIT

# Setup performance testing environment
setup_performance_environment() {
  log_step "Setting up performance testing environment…"

  # Create results directory
  mkdir -p "$RESULTS_DIR"

  # Set environment variables
  export NODE_ENV=production
  export NODE_OPTIONS="--max-old-space-size=2048"

  log_info "Performance testing environment setup completed"
}

# Start application server
start_application_server() {
  local port="${1:-3000}"

  log_step "Starting application server for performance testing…"

  # Build application in production mode
  if [ -f "package.json" ]; then
    if npm run build:prod >/dev/null 2>&1 || npm run build >/dev/null 2>&1; then
      log_info "Application built successfully"
    else
      log_warn "Build failed or no build script found"
    fi

    # Start production server
    if npm run start:prod >/dev/null 2>&1 & then
      SERVER_PID=$!
      log_info "Started production server (PID: $SERVER_PID)"
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

# Run Artillery load tests
run_artillery_tests() {
  local target_url="$1"
  local duration="$2"
  local rate="$3"

  log_step "Running Artillery load tests…"

  if ! command -v artillery >/dev/null 2>&1; then
    log_warn "Artillery not available, skipping Artillery tests"
    return 0
  fi

  # Create Artillery configuration
  cat > "$RESULTS_DIR/artillery-config.yml" << EOF
config:
  target: '$target_url'
  phases:
  - duration: $(echo "$duration" | sed 's/s$//')
    arrivalRate: $(echo "$rate" | sed 's/\/s$//')
  defaults:
  headers:
    User-Agent: 'Artillery Performance Test'
scenarios:
  - name: 'Load test'
  requests:
    - get:
      url: '/'
EOF

  # Run Artillery test
  if artillery run \
    "$RESULTS_DIR/artillery-config.yml" \
    --output "$RESULTS_DIR/artillery-report.json"; then
    
    # Generate HTML report
    artillery report \
      "$RESULTS_DIR/artillery-report.json" \
      --output "$RESULTS_DIR/artillery-report.html" || true

    log_info "Artillery load test completed successfully"
    return 0
  else
    log_error "Artillery load test failed"
    return 1
  fi
}

# Run autocannon load tests
run_autocannon_tests() {
  local target_url="$1"
  local duration="$2"
  local connections="$3"

  log_step "Running autocannon load tests…"

  if ! command -v autocannon >/dev/null 2>&1; then
    log_warn "autocannon not available, skipping autocannon tests"
    return 0
  fi

  # Convert duration to seconds
  local duration_seconds
  duration_seconds=$(echo "$duration" | sed 's/s$//')

  # Run autocannon test
  if autocannon \
    --connections "$connections" \
    --duration "$duration_seconds" \
    --json \
    "$target_url" > "$RESULTS_DIR/autocannon-report.json"; then
    
    log_info "autocannon load test completed successfully"
    
    # Extract key metrics
    if command -v jq >/dev/null 2>&1; then
      local rps
      local latency_avg
      rps=$(jq -r '.requests.average' "$RESULTS_DIR/autocannon-report.json" 2>/dev/null || echo "N/A")
      latency_avg=$(jq -r '.latency.average' "$RESULTS_DIR/autocannon-report.json" 2>/dev/null || echo "N/A")
      
      log_info "Average RPS: $rps"
      log_info "Average Latency: ${latency_avg}ms"
    fi
    
    return 0
  else
    log_error "autocannon load test failed"
    return 1
  fi
}

# Run Lighthouse performance audit
run_lighthouse_audit() {
  local target_url="$1"

  log_step "Running Lighthouse performance audit…"

  if ! command -v lighthouse >/dev/null 2>&1; then
    log_warn "Lighthouse not available, skipping Lighthouse audit"
    return 0
  fi

  # Run Lighthouse audit
  if lighthouse \
    "$target_url" \
    --output=json \
    --output=html \
    --output-path="$RESULTS_DIR/lighthouse" \
    --chrome-flags="--headless --no-sandbox --disable-gpu" \
    --only-categories=performance \
    --throttling-method=simulate; then
    
    log_info "Lighthouse performance audit completed"
    
    # Extract performance score
    if [ -f "$RESULTS_DIR/lighthouse.report.json" ] && command -v jq >/dev/null 2>&1; then
      local perf_score
      perf_score=$(jq -r '.categories.performance.score * 100' "$RESULTS_DIR/lighthouse.report.json" 2>/dev/null || echo "N/A")
      log_info "Performance Score: $perf_score/100"
    fi
    
    return 0
  else
    log_error "Lighthouse performance audit failed"
    return 1
  fi
}

# Run Node.js memory profiling
run_memory_profiling() {
  log_step "Running Node.js memory profiling…"

  if [ -z "$SERVER_PID" ]; then
    log_warn "No server process to profile, skipping memory profiling"
    return 0
  fi

  # Create memory profiling script
  cat > "$RESULTS_DIR/memory-profile.js" << 'EOF'
const v8 = require('v8');
const fs = require('fs');

// Take heap snapshot
function takeHeapSnapshot() {
  const snapshot = v8.writeHeapSnapshot();
  console.log(`Heap snapshot written to: ${snapshot}`);
  return snapshot;
}

// Get memory usage
function getMemoryUsage() {
  const usage = process.memoryUsage();
  const heapStats = v8.getHeapStatistics();
  
  return {
    timestamp: new Date().toISOString(),
    memoryUsage: {
      rss: Math.round(usage.rss / 1024 / 1024),
      heapTotal: Math.round(usage.heapTotal / 1024 / 1024),
      heapUsed: Math.round(usage.heapUsed / 1024 / 1024),
      external: Math.round(usage.external / 1024 / 1024)
    },
    heapStatistics: {
      totalHeapSize: Math.round(heapStats.total_heap_size / 1024 / 1024),
      usedHeapSize: Math.round(heapStats.used_heap_size / 1024 / 1024),
      heapSizeLimit: Math.round(heapStats.heap_size_limit / 1024 / 1024)
    }
  };
}

// Monitor memory for 30 seconds
const measurements = [];
const interval = setInterval(() => {
  measurements.push(getMemoryUsage());
}, 1000);

setTimeout(() => {
  clearInterval(interval);
  
  // Take final heap snapshot
  const snapshot = takeHeapSnapshot();
  
  // Save measurements
  const results = {
    snapshot: snapshot,
    measurements: measurements,
    summary: {
      maxHeapUsed: Math.max(…measurements.map(m => m.memoryUsage.heapUsed)),
      avgHeapUsed: Math.round(measurements.reduce((sum, m) => sum + m.memoryUsage.heapUsed, 0) / measurements.length),
      maxRss: Math.max(…measurements.map(m => m.memoryUsage.rss))
    }
  };
  
  fs.writeFileSync('test-results/performance/memory-profile.json', JSON.stringify(results, null, 2));
  console.log('Memory profiling completed');
  process.exit(0);
}, 30000);
EOF

  # Run memory profiling
  if timeout 35 node "$RESULTS_DIR/memory-profile.js"; then
    log_info "Memory profiling completed"
    
    # Show summary if available
    if [ -f "$RESULTS_DIR/memory-profile.json" ] && command -v jq >/dev/null 2>&1; then
      local max_heap
      local avg_heap
      max_heap=$(jq -r '.summary.maxHeapUsed' "$RESULTS_DIR/memory-profile.json" 2>/dev/null || echo "N/A")
      avg_heap=$(jq -r '.summary.avgHeapUsed' "$RESULTS_DIR/memory-profile.json" 2>/dev/null || echo "N/A")
      
      log_info "Max Heap Used: ${max_heap}MB"
      log_info "Avg Heap Used: ${avg_heap}MB"
    fi
    
    return 0
  else
    log_error "Memory profiling failed"
    return 1
  fi
}

# Run CPU profiling
run_cpu_profiling() {
  log_step "Running CPU profiling…"

  if [ -z "$SERVER_PID" ]; then
    log_warn "No server process to profile, skipping CPU profiling"
    return 0
  fi

  # Create CPU profiling script
  cat > "$RESULTS_DIR/cpu-profile.js" << 'EOF'
const { Session } = require('inspector');
const fs = require('fs');

const session = new Session();
session.connect();

// Start CPU profiling
session.post('Profiler.enable', () => {
  session.post('Profiler.start', () => {
    console.log('CPU profiling started');
    
    // Profile for 30 seconds
    setTimeout(() => {
      session.post('Profiler.stop', (err, { profile }) => {
        if (err) {
          console.error('CPU profiling failed:', err);
          process.exit(1);
        }
        
        // Save profile
        fs.writeFileSync('test-results/performance/cpu-profile.json', JSON.stringify(profile, null, 2));
        console.log('CPU profiling completed');
        
        // Analyze profile
        const functions = profile.nodes || [];
        const hotFunctions = functions
          .filter(node => node.hitCount > 0)
          .sort((a, b) => b.hitCount - a.hitCount)
          .slice(0, 10);
        
        const summary = {
          totalFunctions: functions.length,
          hotFunctions: hotFunctions.map(node => ({
            functionName: node.callFrame.functionName || 'anonymous',
            url: node.callFrame.url,
            hitCount: node.hitCount
          }))
        };
        
        fs.writeFileSync('test-results/performance/cpu-profile-summary.json', JSON.stringify(summary, null, 2));
        
        session.disconnect();
        process.exit(0);
      });
    }, 30000);
  });
});
EOF

  # Run CPU profiling
  if timeout 35 node --inspect=0 "$RESULTS_DIR/cpu-profile.js"; then
    log_info "CPU profiling completed"
    return 0
  else
    log_error "CPU profiling failed"
    return 1
  fi
}

# Generate performance report
generate_performance_report() {
  log_step "Generating performance test report…"

  local report_file="$RESULTS_DIR/summary.json"
  local report_text="$RESULTS_DIR/summary.txt"
  
  # Create JSON report
  cat > "$report_file" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "tests": {
  "artillery": $([ -f "$RESULTS_DIR/artillery-report.json" ] && echo "true" || echo "false"),
  "autocannon": $([ -f "$RESULTS_DIR/autocannon-report.json" ] && echo "true" || echo "false"),
  "lighthouse": $([ -f "$RESULTS_DIR/lighthouse.report.json" ] && echo "true" || echo "false"),
  "memory_profile": $([ -f "$RESULTS_DIR/memory-profile.json" ] && echo "true" || echo "false"),
  "cpu_profile": $([ -f "$RESULTS_DIR/cpu-profile.json" ] && echo "true" || echo "false")
  },
  "success": $([ $EXIT_CODE -eq 0 ] && echo "true" || echo "false")
}
EOF

  # Create text report
  cat > "$report_text" << EOF
PERFORMANCE TEST SUMMARY
=======================
Timestamp: $(date '+%Y-%m-%d %H:%M:%S')

Tests Completed:
EOF

  [ -f "$RESULTS_DIR/artillery-report.json" ] && echo "  ✓ Artillery Load Test" >> "$report_text" || echo "  ✗ Artillery Load Test" >> "$report_text"
  [ -f "$RESULTS_DIR/autocannon-report.json" ] && echo "  ✓ autocannon Load Test" >> "$report_text" || echo "  ✗ autocannon Load Test" >> "$report_text"
  [ -f "$RESULTS_DIR/lighthouse.report.json" ] && echo "  ✓ Lighthouse Audit" >> "$report_text" || echo "  ✗ Lighthouse Audit" >> "$report_text"
  [ -f "$RESULTS_DIR/memory-profile.json" ] && echo "  ✓ Memory Profiling" >> "$report_text" || echo "  ✗ Memory Profiling" >> "$report_text"
  [ -f "$RESULTS_DIR/cpu-profile.json" ] && echo "  ✓ CPU Profiling" >> "$report_text" || echo "  ✗ CPU Profiling" >> "$report_text"

  echo "" >> "$report_text"
  echo "Overall Result: $([ $EXIT_CODE -eq 0 ] && echo "SUCCESS" || echo "FAILURE")" >> "$report_text"

  log_info "Performance report generated"
  cat "$report_text"
}

# Help function
show_help() {
  echo "Performance Test Runner Script"
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  --url URL     - Target URL (default: http://localhost:3000)"
  echo "  --duration TIME   - Test duration (default: $DEFAULT_DURATION)"
  echo "  --rate RATE     - Request rate (default: $DEFAULT_RATE)"
  echo "  --connections N   - Number of connections (default: $DEFAULT_CONNECTIONS)"
  echo "  --artillery     - Run only Artillery tests"
  echo "  --autocannon    - Run only autocannon tests"
  echo "  --lighthouse    - Run only Lighthouse audit"
  echo "  --memory      - Run only memory profiling"
  echo "  --cpu       - Run only CPU profiling"
  echo "  --no-server     - Skip starting application server"
  echo "  --help      - Show this help message"
  echo ""
  echo "Examples:"
  echo "  $0               # Run all performance tests"
  echo "  $0 --artillery         # Run only Artillery load test"
  echo "  $0 --duration 60s --rate 20/s # Custom duration and rate"
  echo "  $0 --url http://example.com   # Test external URL"
}

# Main function
main() {
  local target_url="http://localhost:3000"
  local duration="$DEFAULT_DURATION"
  local rate="$DEFAULT_RATE"
  local connections="$DEFAULT_CONNECTIONS"
  local artillery_only=false
  local autocannon_only=false
  local lighthouse_only=false
  local memory_only=false
  local cpu_only=false
  local start_server=true

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      --url)
        target_url="$2"
        shift 2
        ;;
      --duration)
        duration="$2"
        shift 2
        ;;
      --rate)
        rate="$2"
        shift 2
        ;;
      --connections)
        connections="$2"
        shift 2
        ;;
      --artillery)
        artillery_only=true
        shift
        ;;
      --autocannon)
        autocannon_only=true
        shift
        ;;
      --lighthouse)
        lighthouse_only=true
        shift
        ;;
      --memory)
        memory_only=true
        shift
        ;;
      --cpu)
        cpu_only=true
        shift
        ;;
      --no-server)
        start_server=false
        shift
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

  log_info "Starting performance tests…"
  log_info "Target URL: $target_url"
  log_info "Duration: $duration"
  log_info "Rate: $rate"
  log_info "Connections: $connections"

  # Setup environment
  setup_performance_environment

  # Extract port from URL for server startup
  local port
  port=$(echo "$target_url" | sed -n 's/.*:\([0-9]\+\).*/\1/p')
  [ -z "$port" ] && port=3000

  # Start application server if needed
  if [ "$start_server" = true ] && [[ "$target_url" == http://localhost* ]]; then
    if ! start_application_server "$port"; then
      log_error "Failed to start application server"
      exit 1
    fi
  fi

  # Run performance tests
  if [ "$artillery_only" = true ]; then
    run_artillery_tests "$target_url" "$duration" "$rate" || EXIT_CODE=1
  elif [ "$autocannon_only" = true ]; then
    run_autocannon_tests "$target_url" "$duration" "$connections" || EXIT_CODE=1
  elif [ "$lighthouse_only" = true ]; then
    run_lighthouse_audit "$target_url" || EXIT_CODE=1
  elif [ "$memory_only" = true ]; then
    run_memory_profiling || EXIT_CODE=1
  elif [ "$cpu_only" = true ]; then
    run_cpu_profiling || EXIT_CODE=1
  else
    # Run all available tests
    run_artillery_tests "$target_url" "$duration" "$rate" || true
    run_autocannon_tests "$target_url" "$duration" "$connections" || true
    run_lighthouse_audit "$target_url" || true
    run_memory_profiling || true
    run_cpu_profiling || true
  fi

  # Generate report
  generate_performance_report

  if [ $EXIT_CODE -eq 0 ]; then
    log_info "Performance tests completed successfully"
  else
    log_error "Performance tests failed"
  fi

  exit $EXIT_CODE
}

# Execute main function
main "$@"
