#!/usr/bin/env bash
# Optional, consent-gated zsh-autosuggestions repository installation via mise.
# The single pinned revision is declared in scripts/setup/autosuggestions.toml.
set -euo pipefail

ROOT=$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)

# shellcheck source=scripts/lib/common.sh
source "$ROOT/scripts/lib/common.sh"
# shellcheck source=scripts/lib/mise.sh
source "$ROOT/scripts/lib/mise.sh"

main() {
    usage() {
        printf '%s\n' \
            'Usage: bash scripts/setup/setup-autosuggestions.sh [--apply|--help]' \
            'Default: preview installing the pinned zsh-autosuggestions Git repository.' \
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
    [[ "$(id -u)" != 0 ]] || die 'Do not install user shell plugins as root.'
    manifest="$ROOT/scripts/setup/autosuggestions.toml"
    [[ -f "$manifest" && ! -L "$manifest" ]] || die 'Reviewed plugin manifest is missing.'
    target="$HOME/.local/share/dotfiles/zsh-autosuggestions"
    command -v git >/dev/null 2>&1 || die 'Git is required to install the plugin.'
    mise=$(mise_command) ||
        die 'mise is required for the pinned plugin checkout; run machine bootstrap first.'
    mise_supports_dot "$mise" ||
        die 'mise 2026.11.9 or newer is required for the pinned plugin checkout.'
    # The current checkout's development manifest and normal machine manifest
    # must not participate; use only one reviewed plugin checkout declaration.
    export MISE_GLOBAL_CONFIG_FILE="$manifest"

    if [[ -e "$target" || -L "$target" ]]; then
        if [[ -L "$target" || ! -d "$target/.git" ||
            ! -f "$target/zsh-autosuggestions.zsh" ]]; then
            log "Preserving conflicting existing plugin path at $target; no clone or update attempted."
        elif "$mise" -C / bootstrap repos status --missing >/dev/null 2>&1; then
            log 'The pinned zsh-autosuggestions checkout is already present; no changes made.'
        else
            log "Existing zsh-autosuggestions checkout does not match the pinned manifest; preserving it unchanged: $target."
            log 'Review with: mise -C / bootstrap repos status (with the plugin manifest selected).'
        fi
        exit 0
    fi

    log "Optional pinned zsh-autosuggestions repository destination: $target"
    "$mise" -C / bootstrap repos apply --dry-run ||
        die 'mise could not preview the declared plugin repository checkout.'
    if [[ "$mode" == preview ]]; then
        log 'Preview only; no Git checkout was created. Run --apply to approve.'
        exit 0
    fi
    if ! confirm "Clone the pinned public zsh-autosuggestions release into $target via mise?"; then
        log 'Prompt plugin installation declined; no clone attempted.'
        exit 0
    fi
    # --yes here bypasses mise's second interactive prompt, not this explicit
    # review-and-consent step. Only the one declared repository can be touched.
    "$mise" -C / bootstrap repos apply --yes ||
        die 'mise could not install the pinned zsh-autosuggestions checkout.'
    [[ -d "$target/.git" && -f "$target/zsh-autosuggestions.zsh" ]] ||
        die 'The declared zsh-autosuggestions checkout was not installed as expected.'
    "$mise" -C / bootstrap repos status --missing >/dev/null ||
        die 'The installed zsh-autosuggestions checkout does not match its pinned declaration.'
    log 'zsh-autosuggestions is installed. It loads in new interactive Zsh sessions.'
}

main "$@"
