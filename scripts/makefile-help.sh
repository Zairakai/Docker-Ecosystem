#!/usr/bin/env bash
# scripts/makefile-help.sh
# Display Makefile help with colors using ansi.sh

# Source ANSI helpers
# shellcheck disable=SC1091
# shellcheck disable=SC1091
source "$(dirname "$0")/ansi.sh"

# Display header
mf_header

# Display available commands section
printf "%b\n" "$(style 'Available Commands:' "${BOLD}${FG_CYAN}")"

# Parse Makefile and display commands with section separators
awk -v fg_yellow="${FG_YELLOW}" -v fg_green="${FG_GREEN}" -v reset="${RESET}" -v bold="${BOLD}" '
BEGIN {
    in_commands = 0
    pending_section = ""
}
/^##/ {
    # Store potential section separator
    if (in_commands == 1) {
        pending_section = substr($0, 4)
    }
    next
}
/^[a-zA-Z0-9_-]+:.*##/ {
    # Found a command
    in_commands = 1
    if (pending_section != "") {
        # Print section separator
        printf "\n%s%s%s%s\n", bold, fg_yellow, pending_section, reset
        pending_section = ""
    }
    # Extract target and description
    split($0, parts, ":")
    target = parts[1]
    rest = substr($0, length(target) + 2)
    split(rest, desc_parts, "##")
    description = desc_parts[2]
    gsub(/^ +| +$/, "", description)
    printf "  %s%-28s%s %s\n", fg_green, target, reset, description
}
' Makefile

printf '\n'
