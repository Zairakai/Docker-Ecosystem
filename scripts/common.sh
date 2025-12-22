#!/usr/bin/env bash
# ================================
# COMMON UTILITIES FOR CI/CD SCRIPTS
# ================================
# Provides logging, error handling, and utility functions

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly MAGENTA='\033[0;35m'
readonly BLUE='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly CYAN=${BLUE}
readonly NC='\033[0m' # No Color

# Emoji support (works in GitLab CI)
readonly EMOJI_ERROR="❌"
readonly EMOJI_SUCCESS="✅"
readonly EMOJI_INFO="ℹ️"
readonly EMOJI_WARNING="⚠️"
readonly EMOJI_SECTION="📦"

# Logging functions
log_error() {
  echo -e "${RED}${EMOJI_ERROR} ERROR: $*${NC}" >&2
}

log_success() {
  echo -e "${GREEN}${EMOJI_SUCCESS} $*${NC}"
}

log_info() {
  echo -e "${CYAN}${EMOJI_INFO} $*${NC}"
}

log_warning() {
  echo -e "${YELLOW}${EMOJI_WARNING} WARNING: $*${NC}"
}

log_section() {
  echo -e ""
  echo -e "${MAGENTA}${EMOJI_SECTION} ======================================${NC}"
  echo -e "${MAGENTA}${EMOJI_SECTION} $*${NC}"
  echo -e "${MAGENTA}${EMOJI_SECTION} ======================================${NC}"
  echo -e ""
}

log_debug() {
  if [[ "${DEBUG:-false}" == "true" ]]; then
    echo -e "${WHITE}[DEBUG] $*${NC}" >&2
  fi
}

# Error handling
die() {
  log_error "$@"
  exit 1
}

# Check if command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Validate required commands
require_commands() {
  local missing=()

  for cmd in "$@"; do
    if ! command_exists "$cmd"; then
      missing+=("$cmd")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    die "Missing required commands: ${missing[*]}"
  fi
}

# Validate environment variable exists and is not empty
require_env() {
  local var_name="$1"
  local var_value="${!var_name:-}"

  if [[ -z "${var_value}" ]]; then
    die "Required environment variable ${var_name} is not set"
  fi
}

# Validate multiple environment variables
require_envs() {
  local missing=()

  for var in "$@"; do
    if [[ -z "${!var:-}" ]]; then
      missing+=("$var")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    die "Missing required environment variables: ${missing[*]}"
  fi
}

# Retry a command with exponential backoff
retry() {
  local max_attempts="${1}"
  local delay="${2}"
  local command=("${@:3}")
  local attempt=1

  while [[ $attempt -le $max_attempts ]]; do
    log_info "Attempt ${attempt}/${max_attempts}: ${command[*]}"

    if "${command[@]}"; then
      return 0
    fi

    if [[ $attempt -lt $max_attempts ]]; then
      log_warning "Command failed, retrying in ${delay}s…"
      sleep "$delay"
      delay=$((delay * 2))
    fi

    attempt=$((attempt + 1))
  done

  log_error "Command failed after ${max_attempts} attempts"
  return 1
}

# Execute command with timeout
timeout_exec() {
  local timeout="$1"
  shift
  local command=("$@")

  if command_exists timeout; then
    timeout "$timeout" "${command[@]}"
  else
    # Fallback for systems without timeout command
    "${command[@]}" &
    local pid=$!

    (
      sleep "$timeout"
      kill -TERM "$pid" 2>/dev/null
    ) &
    local killer_pid=$!

    wait "$pid"
    local exit_code=$?

    kill -TERM "$killer_pid" 2>/dev/null
    wait "$killer_pid" 2>/dev/null

    return $exit_code
  fi
}

# Get current timestamp
timestamp() {
  date -u +"%Y-%m-%d %H:%M:%S UTC"
}

# Get current timestamp (compact format)
timestamp_compact() {
  date -u +"%Y%m%d-%H%M%S"
}

# Calculate duration between two timestamps
duration() {
  local start="$1"
  local end="$2"
  echo $((end - start))
}

# Format bytes to human-readable
format_bytes() {
  local bytes="$1"

  if [[ $bytes -lt 1024 ]]; then
    echo "${bytes}B"
  elif [[ $bytes -lt 1048576 ]]; then
    echo "$((bytes / 1024))KB"
  elif [[ $bytes -lt 1073741824 ]]; then
    echo "$((bytes / 1048576))MB"
  else
    echo "$((bytes / 1073741824))GB"
  fi
}

# Check if running in CI environment
is_ci() {
  [[ -n "${CI:-}" ]] || [[ -n "${GITLAB_CI:-}" ]]
}

# Check if running in GitLab CI
is_gitlab_ci() {
  [[ -n "${GITLAB_CI:-}" ]]
}

# Get GitLab project URL
gitlab_project_url() {
  if is_gitlab_ci; then
    echo "${CI_PROJECT_URL:-}"
  fi
}

# Get GitLab pipeline URL
gitlab_pipeline_url() {
  if is_gitlab_ci; then
    echo "${CI_PIPELINE_URL:-}"
  fi
}

# Docker helper functions
docker_image_exists() {
  local image="$1"
  docker manifest inspect "$image" > /dev/null 2>&1
}

docker_image_size() {
  local image="$1"
  docker image inspect "$image" --format='{{.Size}}' 2>/dev/null || echo "0"
}

docker_pull_with_retry() {
  local image="$1"
  local max_attempts="${2:-3}"

  retry "$max_attempts" 5 docker pull "$image"
}

docker_push_with_retry() {
  local image="$1"
  local max_attempts="${2:-3}"

  retry "$max_attempts" 5 docker push "$image"
}

# Cleanup Docker resources
docker_cleanup() {
  log_info "Cleaning up Docker resources…"

  # Remove stopped containers
  docker container prune -f || true

  # Remove dangling images
  docker image prune -f || true

  # Remove unused networks
  docker network prune -f || true

  # Remove unused volumes
  docker volume prune -f || true

  log_success "Docker cleanup completed"
}

# Export all functions
export -f log_error
export -f log_success
export -f log_info
export -f log_warning
export -f log_section
export -f log_debug
export -f die
export -f command_exists
export -f require_commands
export -f require_env
export -f require_envs
export -f retry
export -f timeout_exec
export -f timestamp
export -f timestamp_compact
export -f duration
export -f format_bytes
export -f is_ci
export -f is_gitlab_ci
export -f gitlab_project_url
export -f gitlab_pipeline_url
export -f docker_image_exists
export -f docker_image_size
export -f docker_pull_with_retry
export -f docker_push_with_retry
export -f docker_cleanup
