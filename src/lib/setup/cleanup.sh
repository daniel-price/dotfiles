#!/usr/bin/env bash
# Conservative, opt-in cleanup of the public mise-managed machine setup.
# Does not remove system packages, mise, Git, checkout files or private overlays.
set -euo pipefail

ROOT=$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)

# shellcheck source=src/lib/common.sh
source "$ROOT/src/lib/common.sh"
# shellcheck source=src/lib/mise.sh
source "$ROOT/src/lib/mise.sh"
# shellcheck source=src/lib/machine-tools.sh
source "$ROOT/src/lib/machine-tools.sh"

main() {
    usage() {
        printf '%s\n' \
            'Usage: bash src/lib/setup/cleanup.sh [--apply|--help]' \
            'Default: preview removal of mise-managed dotfiles and pinned tools.' \
            '--apply: approve dotfile removal and each pinned tool interactively (defaults to no).' \
            'Never removes system packages, mise, Git, the checkout or private overlays.'
    }

    mode=preview
    case "${1:-}" in
    -h | --help)
        [[ $# -eq 1 ]] || die 'Unexpected extra argument.'
        usage
        exit 0
        ;;
    '') [[ $# -eq 0 ]] || die 'Unexpected argument.' ;;
    --apply)
        [[ $# -eq 1 ]] || die 'Unexpected extra argument.'
        mode=apply
        ;;
    *) die 'Unknown argument. Use --help for usage.' ;;
    esac

    [[ -n "${HOME:-}" && -d "$HOME" ]] || die 'HOME must be an existing directory.'
    manifest="$ROOT/src/mise.toml"
    [[ -f "$manifest" && ! -L "$manifest" ]] || die 'Reviewed machine manifest is missing.'
    mise=$(mise_command) || die 'mise is unavailable; no cleanup action was taken.'
    mise_supports_dot "$mise" ||
        die 'mise 2026.11.9 or newer is required; no cleanup action was taken.'

    # Prevent repo-development settings from affecting cleanup. Only the explicit
    # reviewed machine manifest is active, even when invoked from another directory.
    export MISE_GLOBAL_CONFIG_FILE="$manifest"
    log 'Only dotfiles and exact pinned tools declared in the machine manifest are eligible.'
    log 'Versions installed by mise are shared with other projects; uninstalling them may affect those projects.'
    log 'System packages, mise, the Git checkout and private profiles are always preserved.'

    # Validate every declared version before any potentially destructive cleanup.
    # A malformed/missing declaration must not remove even the managed symlink.
    tool_specs=$(machine_tool_specs "$mise" "$ROOT/src/home/.config/mise/base-tools.toml") ||
        die 'Could not read exact pinned machine tool declarations; no cleanup action was taken.'

    # Mise discovers targets from the reviewed manifest and removes only entries it
    # recognises as managed. Never force removal of unrelated files or symlinks.
    "$mise" -C / dot unapply --dry-run ||
        die 'mise could not preview reviewed dotfile removal.'
    if [[ "$mode" == apply ]] && confirm 'Remove the reviewed mise-managed dotfiles shown above?'; then
        "$mise" -C / dot unapply --yes ||
            die 'mise failed to remove reviewed dotfiles.'
        log 'Removed approved mise-managed dotfiles.'
    fi

    # Keep the caller's terminal on fd 0: confirm() must see an interactive TTY.
    while IFS= read -r spec <&3; do
        [[ -n "$spec" ]] || continue
        log "Preview removal of shared mise tool version: $spec"
        if "$mise" -C / uninstall --dry-run-code "$spec"; then
            log "$spec is not installed; skipped."
            continue
        else
            status=$?
        fi
        [[ "$status" -eq 1 ]] || die "mise could not inspect $spec for removal."
        if [[ "$mode" == apply ]] && confirm "Uninstall $spec? Other projects might use it."; then
            "$mise" -C / uninstall --yes "$spec" || die "mise could not uninstall $spec."
            log "Uninstalled $spec."
        fi
    done 3<<<"$tool_specs"

    if [[ "$mode" == preview ]]; then
        log 'Preview only; no changes were made. Rerun with --apply to review removals.'
    else
        log 'Cleanup finished. No system packages, private config, mise or checkout files were removed.'
    fi
}

main "$@"
