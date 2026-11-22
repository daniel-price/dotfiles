#!/usr/bin/env bash
# Optional Ghostty installation via a reviewed, isolated mise package manifest.
set -euo pipefail

ROOT=$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)

# shellcheck source=scripts/lib/common.sh
source "$ROOT/scripts/lib/common.sh"
# shellcheck source=scripts/lib/os.sh
source "$ROOT/scripts/lib/os.sh"
# shellcheck source=scripts/lib/mise.sh
source "$ROOT/scripts/lib/mise.sh"

main() {
    usage() {
        printf '%s\n' \
            'Usage: bash scripts/setup/setup-ghostty.sh [--apply|--help]' \
            'Preview optional Ghostty installation via a separate mise package manifest.' \
            '--apply: require explicit approval before installing or adding an APT PPA.' \
            'Linux: supports Pop!_OS/Ubuntu 24.04 from an unofficial community PPA.' \
            'macOS: uses the Homebrew Ghostty cask. No existing app is upgraded.'
    }

    local mode=preview platform package mise os_release
    case "${1:-}" in
    -h | --help)
        [[ $# -eq 1 ]] || die 'Unexpected extra argument.'
        usage
        return
        ;;
    '') [[ $# -eq 0 ]] || die 'Unexpected argument.' ;;
    --apply)
        [[ $# -eq 1 ]] || die 'Unexpected extra argument.'
        mode=apply
        ;;
    *) die 'Unknown argument. Use --help for usage.' ;;
    esac

    [[ -n "${HOME:-}" && -d "$HOME" ]] || die 'HOME must be an existing directory.'
    [[ "$(id -u)" != 0 ]] || die 'Do not bootstrap desktop applications as root.'
    # shellcheck disable=SC2119
    platform=$(detect_os) || die 'Unsupported OS.'
    case "$platform" in
    macos)
        package=brew-cask:ghostty
        if [[ -d /Applications/Ghostty.app || -d "$HOME/Applications/Ghostty.app" ]]; then
            log 'Ghostty.app already exists; not installing or upgrading it.'
            return
        fi
        ;;
    debian)
        # The reviewed PPA is built for Noble; refuse other distro releases.
        os_release=/etc/os-release
        if [[ ! -r "$os_release" ]] ||
            ! grep -Eq '^ID="?(pop|ubuntu)"?$' "$os_release" ||
            ! grep -Eq '^VERSION_ID="?24[.]04"?$' "$os_release" ||
            ! grep -Eq '^UBUNTU_CODENAME="?noble"?$' "$os_release"; then
            log 'Ghostty PPA is enabled only on Pop!_OS/Ubuntu 24.04 (Noble); skipping.'
            return
        fi
        package=apt:ghostty
        ;;
    *) die 'Unsupported platform for Ghostty.' ;;
    esac

    if command -v ghostty >/dev/null 2>&1; then
        log 'Ghostty is already on PATH; not installing or upgrading it.'
        return
    fi

    mise=$(mise_command) ||
        die 'mise is required to install Ghostty; run machine bootstrap first.'
    mise_supports_dot "$mise" ||
        die 'mise 2026.11.9 or newer is required to install Ghostty.'
    export MISE_GLOBAL_CONFIG_FILE="$ROOT/scripts/setup/ghostty.toml"
    [[ -f "$MISE_GLOBAL_CONFIG_FILE" && ! -L "$MISE_GLOBAL_CONFIG_FILE" ]] ||
        die 'Reviewed Ghostty manifest is missing.'

    if [[ "$platform" == debian ]]; then
        log 'Optional UNOFFICIAL Ghostty PPA: mkasberg/ghostty-ubuntu.'
        log 'Approval persists as an APT source; installing it permits future package updates from this maintainer.'
        log 'Ubuntu/Pop!_OS 24.04 supports Ghostty up to 1.3.1.'
    else
        log 'Optional official Ghostty app via Homebrew cask.'
    fi

    "$mise" -C / bootstrap packages apply --dry-run "$package" ||
        die 'Could not preview the reviewed Ghostty package.'
    if [[ "$mode" == preview ]]; then
        log 'Preview only; no package installed or source added. Run --apply to approve.'
        return
    fi

    if ! confirm "Install Ghostty using $package from the reviewed source (including the community PPA on Linux)?"; then
        log 'Ghostty installation declined; nothing changed.'
        return
    fi

    # --yes bypasses mise's second prompt only, never the explicit review above.
    "$mise" -C / bootstrap packages apply --yes "$package" ||
        die 'mise could not install Ghostty; review the package manager output.'
    if ! command -v ghostty >/dev/null 2>&1 &&
        [[ ! -d /Applications/Ghostty.app && ! -d "$HOME/Applications/Ghostty.app" ]]; then
        die 'mise completed, but Ghostty was not found at a standard location.'
    fi
    log 'Ghostty installed; open a new Ghostty window to load the reviewed config.'
}

main "$@"
