#!/usr/bin/env bash
# Sourced library: leave shell options and traps to each entry point.

log() {
    printf '[info] %s\n' "$*"
}

die() {
    printf '[error] %s\n' "$*" >&2
    exit 1
}

report_error() {
    local status=$1
    local line=$2
    printf '[error] %s failed at line %s (exit %s).\n' \
        "${0##*/}" "$line" "$status" >&2
    exit "$status"
}

# Use inside `if confirm 'Describe the exact action'; then ...; fi`.
# Return 0 only for an explicit yes from terminal stdin; never perform an action.
confirm() {
    local answer
    if [[ $# -ne 1 || -z "${1:-}" ]]; then
        printf '[error] confirm requires an action description.\n' >&2
        return 1
    fi
    if [[ ! -t 0 ]]; then
        printf '[info] Declined: confirmation requires interactive stdin.\n' >&2
        return 1
    fi
    printf '%s [y/N] ' "$1" >&2
    if ! IFS= read -r answer; then
        return 1
    fi
    case "$answer" in
        [yY]|[yY][eE][sS]) return 0 ;;
        *) return 1 ;;
    esac
}
