#!/usr/bin/env bash
# Sourced library: leave shell options and traps to each entry point.

# Create a temporary directory and return its physical path. Git may report
# /private/var where mktemp returns /var on macOS.
make_temp_dir_physical() {
    local dir
    dir=$(mktemp -d "${TMPDIR:-/tmp}/$1.XXXXXX") || return
    (cd "$dir" && pwd -P)
}

log() {
    printf '[info] %s\n' "$*"
}

# Completed setup stages share the same status format as run_step.
success() {
    printf '✓ %s\n' "$*"
}

die() {
    printf '[error] %s\n' "$*" >&2
    exit 1
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
    # Read a single keypress without Enter. -s suppresses terminal echo;
    # -n 1 temporarily switches the terminal to character-at-a-time input.
    if ! IFS= read -r -s -n 1 answer; then
        printf '\n' >&2
        return 1
    fi
    printf '\n' >&2
    [[ "$answer" == [yY] ]]
}

# Only wrap non-interactive operations. Keep diagnostics on failure and warnings
# on success; never redirect confirmation prompts or package installer input.
run_concise() {
    local output status=0
    if [[ "${DOTFILES_VERBOSE:-true}" == true ]]; then
        if [[ -n "${DOTFILES_LOG_FILE:-}" ]]; then
            "$@" 2>&1 | tee -a "$DOTFILES_LOG_FILE"
            return "${PIPESTATUS[0]}"
        fi
        "$@"
        return $?
    fi
    output=$(mktemp "${TMPDIR:-/tmp}/dotfiles-output.XXXXXX") || return 2
    "$@" >"$output" 2>&1 || status=$?
    if [[ -n "${DOTFILES_LOG_FILE:-}" ]]; then
        cat "$output" >>"$DOTFILES_LOG_FILE" || :
    fi
    if ((status != 0)); then
        cat "$output" >&2
    else
        grep -Ei '(^|[^[:alnum:]])(warn(ing)?|error|fatal)([^[:alnum:]]|$)' "$output" >&2 || :
    fi
    rm -f -- "$output" || :
    return "$status"
}
