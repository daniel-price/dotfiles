#!/usr/bin/env bash
set -euo pipefail

ROOT=$(CDPATH='' cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
# shellcheck source=scripts/lib/common.sh
source "$ROOT/scripts/lib/common.sh"
# shellcheck source=scripts/lib/os.sh
source "$ROOT/scripts/lib/os.sh"
trap 'report_error "$?" "$LINENO"' ERR

GHOSTTY_PPA='ppa:mkasberg/ghostty-ubuntu'
GHOSTTY_PPA_TOKEN='mkasberg/ghostty-ubuntu'

usage() {
    printf '%s\n' \
        'Usage: bash scripts/install-ghostty.sh [--help]' \
        'Install Ghostty with apt on Debian/Ubuntu or a Homebrew cask on macOS.' \
        'Skips an existing installation and never upgrades it.'
}

run_privileged() {
    if [[ "$(id -u)" -eq 0 ]]; then
        "$@"
    else
        command -v sudo >/dev/null 2>&1 || die 'Installing Ghostty requires sudo.'
        sudo "$@"
    fi
}

ghostty_ready() {
    local platform=$1 status
    if [[ "$platform" == macos ]]; then
        [[ -d /Applications/Ghostty.app ]] && return 0
        command -v brew >/dev/null 2>&1 || return 1
        brew list --cask ghostty >/dev/null 2>&1 && return 0
        return 1
    fi
    if command -v dpkg-query >/dev/null 2>&1; then
        status=$(dpkg-query -W -f='${Status}' ghostty 2>/dev/null || :)
        [[ "$status" == *'install ok installed'* ]] && return 0
    fi
    command -v ghostty >/dev/null 2>&1 && return 0
    return 1
}

apt_candidate() {
    LC_ALL=C apt-cache policy ghostty 2>/dev/null |
        awk '/Candidate:/ {print $2; exit}'
}

ppa_configured() {
    local file
    for file in /etc/apt/sources.list /etc/apt/sources.list.d/*.list \
        /etc/apt/sources.list.d/*.sources; do
        [[ -r "$file" ]] || continue
        grep -Fq "$GHOSTTY_PPA_TOKEN" "$file" && return 0
    done
    return 1
}

install_macos() {
    command -v brew >/dev/null 2>&1 ||
        die 'Homebrew is unavailable; install it separately before installing Ghostty.'
    if ! confirm 'Install Ghostty with HOMEBREW_NO_AUTO_UPDATE=1 brew install --cask ghostty?'; then
        log 'Skipped Ghostty installation; no Homebrew command ran.'
        return 2
    fi
    HOMEBREW_NO_AUTO_UPDATE=1 brew install --cask ghostty ||
        die 'Homebrew failed to install Ghostty.'
}

install_debian() {
    command -v apt-get >/dev/null 2>&1 || die 'Cannot install Ghostty: apt-get is unavailable.'
    command -v apt-cache >/dev/null 2>&1 || die 'Cannot check Ghostty: apt-cache is unavailable.'

    local candidate
    candidate=$(apt_candidate)
    if [[ -z "$candidate" || "$candidate" == '(none)' ]]; then
        if ppa_configured; then
            die 'Ghostty is not available from the configured apt repositories; refresh package lists explicitly.'
        fi
        command -v add-apt-repository >/dev/null 2>&1 ||
            die 'Ghostty is unavailable from apt and add-apt-repository is missing; configure an approved source first.'
        if ! confirm "Add $GHOSTTY_PPA and refresh apt package lists?"; then
            log 'Skipped adding the Ghostty PPA; no repository change made.'
            return 2
        fi
        run_privileged add-apt-repository -y "$GHOSTTY_PPA" ||
            die 'Could not add the Ghostty PPA.'
        candidate=$(apt_candidate)
    fi

    if [[ -z "$candidate" || "$candidate" == '(none)' ]]; then
        die 'Ghostty is still unavailable from apt; no package was installed.'
    fi
    if ! confirm "Install Ghostty $candidate with apt-get install ghostty?"; then
        log 'Skipped Ghostty installation; no apt command ran.'
        return 2
    fi
    run_privileged apt-get install ghostty || die 'apt-get failed to install Ghostty.'
}

if [[ $# -gt 1 ]]; then
    die 'Expected no arguments or --help.'
fi
case "${1:-}" in
-h | --help)
    usage
    exit 0
    ;;
'') ;;
*) die 'Unknown argument. Use --help for usage.' ;;
esac

# shellcheck disable=SC2119
platform=$(detect_os)
if ghostty_ready "$platform"; then
    log 'Ghostty is already installed; skipped.'
    exit 0
fi

status=0
case "$platform" in
macos) install_macos || status=$? ;;
debian) install_debian || status=$? ;;
*) die "Unsupported platform: $platform." ;;
esac
[[ "$status" -eq 2 ]] && exit 0
[[ "$status" -eq 0 ]] || die 'Ghostty installation did not complete.'

ghostty_ready "$platform" || die 'Ghostty is not detected after installation.'
log 'Installed Ghostty.'
