#!/usr/bin/env bash
# Sourced helper: caller owns shell options. Only wrap noninteractive, nonsecret commands.

logging_init() {
    local state_dir log_dir
    state_dir=${XDG_STATE_HOME:-${HOME:?}/.local/state}
    log_dir="$state_dir/dotfiles/logs"
    (
        umask 077
        mkdir -p -- "$log_dir"
    ) || return 1
    [[ -d "$log_dir" && ! -L "$log_dir" && -O "$log_dir" ]] || return 1
    chmod 700 "$log_dir" || return 1
    if [[ -n "${DOTFILES_LOG_FILE:-}" ]]; then
        [[ "$DOTFILES_LOG_FILE" == "$log_dir"/bootstrap-* && -f "$DOTFILES_LOG_FILE" &&
            ! -L "$DOTFILES_LOG_FILE" && -O "$DOTFILES_LOG_FILE" && -w "$DOTFILES_LOG_FILE" ]] || return 1
        chmod 600 "$DOTFILES_LOG_FILE"
        return $?
    fi
    DOTFILES_LOG_FILE=$(
        umask 077
        mktemp "$log_dir/bootstrap-$(date +%Y%m%d-%H%M%S)-XXXXXX"
    ) || return 1
    export DOTFILES_LOG_FILE
}

# Routine information is retained in the run log; warnings and errors stay visible.
info() {
    if [[ -n "${DOTFILES_LOG_FILE:-}" ]]; then
        printf '[info] %s\n' "$*" >>"$DOTFILES_LOG_FILE" || return 1
    fi
    if [[ "${DOTFILES_VERBOSE:-true}" == true || -z "${DOTFILES_LOG_FILE:-}" ]]; then
        printf '[info] %s\n' "$*"
    fi
}
warn() { printf '[warn] %s\n' "$*" >&2; }
error() { printf '[error] %s\n' "$*" >&2; }

# Run the actual command exactly once, independently of the cosmetic spinner.
# The parent waits for the command, never for Gum's interpretation of its status.
# Gum only observes the worker's lifetime; it does not own the provisioning work.
logging_spin() {
    local description=$1 worker status=0
    shift
    "$@" </dev/null >>"$DOTFILES_LOG_FILE" 2>&1 &
    worker=$!
    # shellcheck disable=SC2016
    if ! "$DOTFILES_GUM" spin --title "$description" -- bash -c '
        while kill -0 "$1" 2>/dev/null; do
            sleep 0.1
        done
    ' dotfiles-spin "$worker"; then
        unset DOTFILES_GUM
        warn 'Gum spinner failed; using plain-text progress.'
    fi
    wait "$worker" || status=$?
    return "$status"
}

# Private steps do not log or echo subprocess output, even in verbose mode.
# Never wrap a command that needs the terminal for input (sudo/chsh/prompts).
run_step() {
    local private=false description status=0 offset plain_progress=false
    local -a pipeline_status
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
        "$@" </dev/null >/dev/null 2>&1 || status=$?
    else
        printf '\n=== %s: %s ===\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$description" >>"$DOTFILES_LOG_FILE" || return 2
        offset=$(wc -c <"$DOTFILES_LOG_FILE") || return 2
        if [[ "${DOTFILES_VERBOSE:-false}" == true ]]; then
            printf '%s\n' "$description"
            if "$@" </dev/null 2>&1 | tee -a "$DOTFILES_LOG_FILE"; then
                pipeline_status=("${PIPESTATUS[@]}")
            else
                pipeline_status=("${PIPESTATUS[@]}")
            fi
            status=${pipeline_status[0]}
            if ((status == 0 && pipeline_status[1] != 0)); then
                status=${pipeline_status[1]}
            fi
        elif [[ -t 1 && -t 2 && -x "${DOTFILES_GUM:-}" && "${TERM:-dumb}" != dumb ]]; then
            logging_spin "$description" "$@" || status=$?
        else
            if [[ -t 1 && -t 2 && "${TERM:-dumb}" != dumb ]]; then
                printf '%s...' "$description"
                plain_progress=true
            fi
            "$@" </dev/null >>"$DOTFILES_LOG_FILE" 2>&1 || status=$?
        fi
        printf '[exit %s]\n' "$status" >>"$DOTFILES_LOG_FILE" || warn 'Could not finish writing the step log.'
    fi
    if [[ "$plain_progress" == true ]]; then
        printf '\r\033[2K'
    fi
    if ((status == 0)); then
        printf '✓ %s\n' "$description"
    else
        printf '✗ %s failed (exit %s).\n' "$description" "$status" >&2
        if [[ "$private" == false ]]; then
            if [[ "${DOTFILES_VERBOSE:-false}" != true ]]; then
                # Only show diagnostics from this step, never earlier steps.
                tail -c "+$((offset + 1))" "$DOTFILES_LOG_FILE" | tail -n 8 >&2 || :
            fi
            error "Full details: $DOTFILES_LOG_FILE"
        fi
    fi
    return "$status"
}

# Standalone helpers retain their original output unless called by bootstrap.
run_provision_step() {
    if [[ -n "${DOTFILES_LOG_FILE:-}" ]]; then
        run_step "$@"
    else
        shift
        "$@"
    fi
}
