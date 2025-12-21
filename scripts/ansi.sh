#!/usr/bin/env bash
# scripts/ansi.sh
# ANSI helper for Makefile and shell scripts
# Usage: source scripts/ansi.sh

# Respect NO_COLOR (RFC: if set to 1 -> disable)
if [ "${NO_COLOR:-0}" = "1" ]; then
  ESC=""
  RESET=""
  BOLD=""
  ITALIC=""
  UNDERLINE=""
  INVERSE=""
  STRIKE=""
  # colors empty…
  for c in BLACK RED GREEN YELLOW BLUE MAGENTA CYAN WHITE BBLACK BRED BG_BWHITE; do
    declare -g "FG_${c}=" || true
    declare -g "BG_${c}=" || true
  done
else
  # All color/style variables are exported for use by scripts that source this file
  # shellcheck disable=SC2034
  ESC="\033["
  # shellcheck disable=SC2034
  RESET="${ESC}0m"
  # shellcheck disable=SC2034
  BOLD="${ESC}1m"
  # shellcheck disable=SC2034
  ITALIC="${ESC}3m"
  # shellcheck disable=SC2034
  UNDERLINE="${ESC}4m"
  # shellcheck disable=SC2034
  INVERSE="${ESC}7m"
  # shellcheck disable=SC2034
  STRIKE="${ESC}9m"

  # shellcheck disable=SC2034
  FG_BLACK="${ESC}30m"
  # shellcheck disable=SC2034
  FG_RED="${ESC}31m"
  # shellcheck disable=SC2034
  FG_GREEN="${ESC}32m"
  # shellcheck disable=SC2034
  FG_YELLOW="${ESC}33m"
  # shellcheck disable=SC2034
  FG_BLUE="${ESC}34m"
  # shellcheck disable=SC2034
  FG_MAGENTA="${ESC}35m"
  # shellcheck disable=SC2034
  FG_CYAN="${ESC}36m"
  # shellcheck disable=SC2034
  FG_WHITE="${ESC}37m"
  # shellcheck disable=SC2034
  FG_BBLACK="${ESC}90m"
  # shellcheck disable=SC2034
  FG_BRED="${ESC}91m"
  # shellcheck disable=SC2034
  FG_BGREEN="${ESC}92m"
  # shellcheck disable=SC2034
  FG_BYELLOW="${ESC}93m"
  # shellcheck disable=SC2034
  FG_BBLUE="${ESC}94m"
  # shellcheck disable=SC2034
  FG_BMAGENTA="${ESC}95m"
  # shellcheck disable=SC2034
  FG_BCYAN="${ESC}96m"
  # shellcheck disable=SC2034
  FG_BWHITE="${ESC}97m"

  # shellcheck disable=SC2034
  BG_BLACK="${ESC}40m"
  # shellcheck disable=SC2034
  BG_RED="${ESC}41m"
  # shellcheck disable=SC2034
  BG_GREEN="${ESC}42m"
  # shellcheck disable=SC2034
  BG_YELLOW="${ESC}43m"
  # shellcheck disable=SC2034
  BG_BLUE="${ESC}44m"
  # shellcheck disable=SC2034
  BG_MAGENTA="${ESC}45m"
  # shellcheck disable=SC2034
  BG_CYAN="${ESC}46m"
  # shellcheck disable=SC2034
  BG_WHITE="${ESC}47m"
  # shellcheck disable=SC2034
  BG_BBLACK="${ESC}100m"
  # shellcheck disable=SC2034
  BG_BRED="${ESC}101m"
  # shellcheck disable=SC2034
  BG_BGREEN="${ESC}102m"
  # shellcheck disable=SC2034
  BG_BYELLOW="${ESC}103m"
  # shellcheck disable=SC2034
  BG_BBLUE="${ESC}104m"
  # shellcheck disable=SC2034
  BG_BMAGENTA="${ESC}105m"
  # shellcheck disable=SC2034
  BG_BCYAN="${ESC}106m"
  # shellcheck disable=SC2034
  BG_BWHITE="${ESC}107m"
fi

# Helper: style a text with given prefix and suffix (no newline)
# Example: style "text" "${BOLD}${FG_GREEN}"
style() {
  local text="$1"; shift
  local start="$1"; shift || start=""
  local end="${1:-$RESET}"
  printf "%b%s%b" "$start" "$text" "$end"
}

# Quick print helpers (newline added)
log() {
  printf "%b\n$*";
}

separator() {
  local char=${1:-=}
  local count=${2:-50}
  printf "${char}%.0s" $(seq 1 "$count")
  echo
}

info() {
  printf "%b\n" "$(style "[INFO] " "${BOLD}${FG_CYAN}")$*";
}
ok() {
  printf "%b\n" "$(style "[ OK ] " "${BOLD}${FG_GREEN}")$*";
}
warn() {
  printf "%b\n" "$(style "[WARN] " "${BOLD}${FG_YELLOW}")$*";
}
err() {
  printf "%b\n" "$(style "[ERROR] " "${BOLD}${FG_RED}")$*";
}

# Makefile-friendly header
mf_header() {
  printf "\n"
  printf "%b\n" "$(style "────────────────────────────────────────────────────────────────────" "${FG_BLUE}")"
  printf "%b\n" "$(style "──────────────────── Zairakai - Docker Ecosystem ───────────────────" "${BOLD}${FG_CYAN}")"
  printf "%b\n" "$(style "────────────────────────────────────────────────────────────────────" "${FG_BLUE}")"
  printf "\n"
}

# Export helpers for shells that support exported functions
export -f style info ok warn err mf_header || true
