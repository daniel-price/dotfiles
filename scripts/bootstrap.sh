#!/usr/bin/env bash
set -euo pipefail

ROOT=$(CDPATH='' cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
# shellcheck source=scripts/lib/common.sh
source "$ROOT/scripts/lib/common.sh"
# shellcheck source=scripts/lib/os.sh
source "$ROOT/scripts/lib/os.sh"
trap 'report_error "$?" "$LINENO"' ERR

usage() {
    printf '%s\n' \
        'Usage: bash scripts/bootstrap.sh [--help]' \
        'Install missing zsh and curl only after separate confirmation.' \
        'Does not configure the shell, install mise, deploy dotfiles or upgrade software.'
}

tool_ready() {
    command -v "$1" >/dev/null 2>&1 && "$1" --version >/dev/null 2>&1
}

install_debian_tool() {
    local tool=$1
    command -v apt-get >/dev/null 2>&1 ||
        die "Cannot install missing $tool: apt-get is unavailable."

    if [[ "$(id -u)" -eq 0 ]]; then
        confirm "Install missing $tool with apt-get install --no-upgrade $tool?" || return 1
        apt-get install --no-upgrade "$tool" || die "Failed to install $tool with apt-get."
    else
        command -v sudo >/dev/null 2>&1 ||
            die "Cannot install missing $tool: sudo is unavailable."
        confirm "Install missing $tool with sudo apt-get install --no-upgrade $tool?" ||
            return 1
        sudo apt-get install --no-upgrade "$tool" ||
            die "Failed to install $tool with apt-get."
    fi
}

install_macos_tool() {
    local tool=$1
    command -v brew >/dev/null 2>&1 ||
        die "Cannot install missing $tool: Homebrew is unavailable. Install Homebrew separately, then rerun."

    confirm "Install missing $tool with HOMEBREW_NO_AUTO_UPDATE=1 brew install $tool?" ||
        return 1
    HOMEBREW_NO_AUTO_UPDATE=1 brew install "$tool" ||
        die "Failed to install $tool with Homebrew."
}

ensure_tool() {
    local platform=$1
    local tool=$2
    if tool_ready "$tool"; then
        log "$tool is available; no installation needed."
        return
    fi

    case "$platform" in
    debian)
        if ! install_debian_tool "$tool"; then
            log "Skipped $tool installation; $tool remains unavailable."
            return
        fi
        ;;
    macos)
        if ! install_macos_tool "$tool"; then
            log "Skipped $tool installation; $tool remains unavailable."
            return
        fi
        ;;
    *) die "Unsupported platform: $platform." ;;
    esac

    tool_ready "$tool" || die "$tool is still unavailable after installation."
    log "Installed $tool."
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

# No arguments selects host detection rather than test fixture parameters.
# shellcheck disable=SC2119
platform=$(detect_os)
log "Detected platform: $platform."
ensure_tool "$platform" zsh
ensure_tool "$platform" curl
log 'Bootstrap complete. Not implemented: SSH setup, mise installation, dotfile deployment,'
log 'Git updates, or shell configuration.'
