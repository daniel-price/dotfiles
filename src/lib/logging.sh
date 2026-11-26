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
        elif [[ -t 1 && -t 2 && -n "${DOTFILES_GUM_MISE:-}" ]]; then
            marker=$(
                umask 077
                mktemp "${TMPDIR:-/tmp}/dotfiles-step-XXXXXX"
            ) || return 2
            rm -f -- "$marker"
            DOTFILES_STEP_RESULT="$marker" "$DOTFILES_GUM_MISE" -C / exec -- \
                gum spin --title "$description" -- bash -c '
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
                warn 'Gum spinner failed; continuing with plain-text output.'
                status=0
                "$@" >>"$DOTFILES_LOG_FILE" 2>&1 || status=$?
            fi
            rm -f -- "$marker"
        else
            info "$description..."
            "$@" >>"$DOTFILES_LOG_FILE" 2>&1 || status=$?
        fi
    fi
    if ((status == 0)); then
        printf '✓ %s\n' "$description"
    else
        error "$description failed (exit $status)."
        if [[ "$private" == false ]]; then
            if [[ "${DOTFILES_VERBOSE:-false}" != true ]]; then
                tail -n 8 "$DOTFILES_LOG_FILE" >&2 || :
            fi
            error "Full details: $DOTFILES_LOG_FILE"
        fi
    fi
    return "$status"
}
