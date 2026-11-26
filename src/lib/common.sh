#!/usr/bin/env bash
# Sourced library: leave shell options and traps to each entry point.

# Create a temporary directory and return its physical path. Git may report
# /private/var where mktemp returns /var on macOS.
make_temp_dir_physical() {
    local dir
    dir=$(mktemp -d "${TMPDIR:-/tmp}/$1.XXXXXX") || return
    (cd "$dir" && pwd -P)
}

# A bootstrap log is inherited by every setup script. Standalone commands
# retain their normal output, while bootstrap has a single presentation policy.
log() {
    if [[ -n "${DOTFILES_LOG_FILE:-}" ]]; then
        printf '[info] %s\n' "$*" >>"$DOTFILES_LOG_FILE" || :
        if [[ "${DOTFILES_VERBOSE:-false}" != true ]]; then
            return 0
        fi
    fi
    printf '[info] %s\n' "$*"
}

report_error() {
    if [[ -n "${DOTFILES_LOG_FILE:-}" ]]; then
        printf '[error] %s\n' "$*" >>"$DOTFILES_LOG_FILE" || :
        printf '✗ %s (log: %s)\n' "$*" "$DOTFILES_LOG_FILE" >&2
    else
        printf '[error] %s\n' "$*" >&2
    fi
}

die() {
    report_error "$@"
    exit 1
}

# Use inside `if confirm 'Describe the exact action'; then ...; fi`.
# Return 0 only for an explicit yes from terminal stdin; never perform an action.
confirm() {
    local answer='' prompt terminal_size height width rows=0 clear_prompt=false approved=false
    if [[ $# -ne 1 || -z "${1:-}" ]]; then
        report_error 'confirm requires an action description.'
        return 1
    fi
    if [[ ! -t 0 ]]; then
        log 'Declined: confirmation requires interactive stdin.' >&2
        return 1
    fi
    prompt="? $1 [y/N] "
    # Only rewrite a real terminal during quiet bootstrap. Count explicitly
    # wrapped rows (including the prompt suffix); avoid erasing unrelated text
    # if the terminal size is unknown or the prompt contains control characters.
    if [[ -n "${DOTFILES_LOG_FILE:-}" && "${DOTFILES_VERBOSE:-false}" != true &&
        -t 2 && "${TERM:-dumb}" != dumb && ! "$prompt" =~ [[:cntrl:]] ]]; then
        if terminal_size=$(stty size 2>/dev/null); then
            read -r height width <<<"$terminal_size"
            if [[ "$height" =~ ^[0-9]+$ && "$width" =~ ^[0-9]+$ ]] &&
                ((height > 0 && width > 0)); then
                rows=$(((${#prompt} - 1) / width))
                if ((rows < height)); then
                    clear_prompt=true
                fi
            fi
        fi
    fi
    printf '%s' "$prompt" >&2
    # Read a single keypress without Enter. -s suppresses terminal echo;
    # -n 1 temporarily switches the terminal to character-at-a-time input.
    if IFS= read -r -s -n 1 answer && [[ "$answer" == [yY] ]]; then
        approved=true
    fi
    if [[ "$clear_prompt" == true ]]; then
        printf '\r\033[2K' >&2
        while ((rows > 0)); do
            printf '\033[1A\r\033[2K' >&2
            rows=$((rows - 1))
        done
    else
        printf '\n' >&2
    fi
    if [[ "$approved" == true ]]; then
        return 0
    fi
    if [[ -n "${DOTFILES_LOG_FILE:-}" && "${DOTFILES_VERBOSE:-false}" != true ]]; then
        printf '✗ Declined: %s\n' "${1%\?}" >&2
    fi
    return 1
}

# Only wrap non-interactive operations. Keep diagnostics on failure and warnings
# on success; never redirect confirmation prompts or package installer input.
run_concise() {
    local output status=0
    if [[ -n "${DOTFILES_LOG_FILE:-}" && "${DOTFILES_VERBOSE:-false}" != true ]]; then
        "$@" >>"$DOTFILES_LOG_FILE" 2>&1
        return $?
    fi
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
