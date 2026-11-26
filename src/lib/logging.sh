#!/usr/bin/env bash
# Sourced helper: caller owns shell options. Only wrap noninteractive, nonsecret commands.

logging_init() {
    local state_dir log_dir
    if [[ -n "${DOTFILES_LOG_FILE:-}" ]]; then
        [[ -f "$DOTFILES_LOG_FILE" && ! -L "$DOTFILES_LOG_FILE" && -w "$DOTFILES_LOG_FILE" ]]
        return $?
    fi
    state_dir=${XDG_STATE_HOME:-${HOME:?}/.local/state}
    log_dir="$state_dir/dotfiles/logs"
    (
        umask 077
        mkdir -p -- "$log_dir"
    ) || return 1
    [[ -d "$log_dir" && ! -L "$log_dir" ]] || return 1
    DOTFILES_LOG_FILE=$(
        umask 077
        mktemp "$log_dir/bootstrap-$(date +%Y%m%d-%H%M%S)-XXXXXX"
    ) || return 1
    export DOTFILES_LOG_FILE
}

info() { printf '[info] %s\n' "$*"; }
warn() { printf '[warn] %s\n' "$*" >&2; }
error() { printf '[error] %s\n' "$*" >&2; }

# Private steps do not log or echo subprocess output, even in verbose mode.
# Never wrap a command that needs the terminal for input (sudo/chsh/prompts).
run_step() {
    local private=false description status=0 marker='' step_status
    if [[ "${1:-}" == --sensitive ]]; then
        private=true
        shift
    fi
    description=${1:-}
    [[ -n "$description" && $# -ge 2 ]] || {
        error 'run_step requires a description and command.'
        return 2
    }
    shift
    logging_init || {
        error 'Cannot initialise the private bootstrap log.'
        return 2
    }
    if [[ "$private" == true ]]; then
        "$@" >/dev/null 2>&1 || status=$?
    else
        printf '\n=== %s: %s ===\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$description" >>"$DOTFILES_LOG_FILE" || return 2
        if [[ "${DOTFILES_VERBOSE:-false}" == true ]]; then
            info "$description..."
            if "$@" 2>&1 | tee -a "$DOTFILES_LOG_FILE"; then
                status=${PIPESTATUS[0]}
            else
                status=${PIPESTATUS[0]}
            fi
        elif [[ -t 1 && -n "${DOTFILES_GUM_BIN:-}" ]]; then
            marker=$(
                umask 077
                mktemp "${TMPDIR:-/tmp}/dotfiles-step-XXXXXX"
            ) || return 2
            rm -f -- "$marker"
            # Intentionally expanded in the child Bash, not this parent shell.
            # shellcheck disable=SC2016
            DOTFILES_STEP_RESULT="$marker" "$DOTFILES_GUM_BIN" spin --title "$description" -- bash -c '
                    "$@" >>"$DOTFILES_LOG_FILE" 2>&1
                    result=$?
                    printf "%s\n" "$result" > "$DOTFILES_STEP_RESULT"
                    exit "$result"
                ' dotfiles-step "$@" || status=$?
            if [[ -f "$marker" ]]; then
                step_status=$(<"$marker")
                [[ "$step_status" =~ ^[0-9]+$ ]] || {
                    rm -f -- "$marker"
                    return 2
                }
                status=$step_status
            else
                warn 'Gum spinner did not report command completion; refusing to repeat the operation.'
                ((status != 0)) || status=1
            fi
            rm -f -- "$marker"
        else
            if [[ -t 1 ]]; then
                printf '… %s\r' "$description"
            fi
            "$@" >>"$DOTFILES_LOG_FILE" 2>&1 || status=$?
            if [[ -t 1 ]]; then
                printf '\r\033[K'
            fi
        fi
    fi
    if ((status == 0)); then
        printf '✓ %s\n' "$description"
    else
        printf '✗ %s failed (exit %s).\n' "$description" "$status" >&2
        if [[ "$private" == false ]]; then
            error "Full details: $DOTFILES_LOG_FILE"
        fi
    fi
    return "$status"
}
