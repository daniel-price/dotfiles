#!/usr/bin/env bash
# Optional, consent-gated Powerlevel10k repository installation via mise.
# The single pinned revision is declared in src/lib/setup/prompt.toml.
set -euo pipefail

ROOT=$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)

# shellcheck source=src/lib/common.sh
source "$ROOT/src/lib/common.sh"
# shellcheck source=src/lib/logging.sh
source "$ROOT/src/lib/logging.sh"
# shellcheck source=src/lib/mise.sh
source "$ROOT/src/lib/mise.sh"

main() {
    usage() {
        printf '%s\n' \
            'Usage: bash src/lib/setup/setup-prompt.sh [--apply|--help]' \
            'Default: preview installing the pinned Powerlevel10k Git repository.' \
            '--apply: offer the clone with one terminal confirmation (default No).' \
            'Existing checkouts are never updated, overwritten or removed.'
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

    [[ -n "${HOME:-}" && -d "$HOME" ]] || die 'HOME must exist.'
    [[ "$(id -u)" != 0 ]] || die 'Do not install user shell themes as root.'
    manifest="$ROOT/src/lib/setup/prompt.toml"
    [[ -f "$manifest" && ! -L "$manifest" ]] || die 'Reviewed prompt manifest is missing.'
    target="$HOME/.local/share/dotfiles/powerlevel10k"
    command -v git >/dev/null 2>&1 || die 'Git is required to install the prompt theme.'
    mise=$(mise_command) ||
        die 'mise is required for the pinned prompt checkout; run machine bootstrap first.'
    mise_supports_dot "$mise" ||
        die 'mise 2026.11.9 or newer is required for the pinned prompt checkout.'
    # The current checkout's development manifest and normal machine manifest
    # must not participate; use only one reviewed prompt checkout declaration.
    export MISE_GLOBAL_CONFIG_FILE="$manifest"

    if [[ -e "$target" || -L "$target" ]]; then
        if [[ -L "$target" || ! -d "$target/.git" ||
            ! -f "$target/powerlevel10k.zsh-theme" ]]; then
            log "Preserving conflicting existing prompt path at $target; no clone or update attempted."
        elif "$mise" -C / bootstrap repos status --missing >/dev/null 2>&1; then
            log 'The pinned Powerlevel10k checkout is already present; no changes made.'
        else
            log "Existing Powerlevel10k checkout does not match the pinned manifest; preserving it unchanged: $target."
            log 'Review with: mise -C / bootstrap repos status (with the prompt manifest selected).'
        fi
        exit 0
    fi

    log "Optional pinned Powerlevel10k repository destination: $target"
    "$mise" -C / bootstrap repos apply --dry-run ||
        die 'mise could not preview the declared prompt repository checkout.'
    if [[ "$mode" == preview ]]; then
        log 'Preview only; no Git checkout was created. Run --apply to approve.'
        exit 0
    fi
    if ! confirm "Clone the pinned public Powerlevel10k release into $target via mise?"; then
        log 'Prompt theme installation declined; no clone attempted.'
        exit 0
    fi
    # --yes here bypasses mise's second interactive prompt, not this explicit
    # review-and-consent step. Only the one declared repository can be touched.
    run_provision_step 'Installing Powerlevel10k' "$mise" -C / bootstrap repos apply --yes ||
        die 'mise could not install the pinned Powerlevel10k checkout.'
    [[ -d "$target/.git" && -f "$target/powerlevel10k.zsh-theme" ]] ||
        die 'The declared Powerlevel10k checkout was not installed as expected.'
    "$mise" -C / bootstrap repos status --missing >/dev/null ||
        die 'The installed Powerlevel10k checkout does not match its pinned declaration.'
    log 'Powerlevel10k is installed. Its original prompt config activates in new Zsh sessions.'
}

main "$@"
