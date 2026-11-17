#!/usr/bin/env bash
set -euo pipefail

ROOT=$(CDPATH='' cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
# shellcheck source=scripts/lib/common.sh
source "$ROOT/scripts/lib/common.sh"
# shellcheck source=scripts/lib/os.sh
source "$ROOT/scripts/lib/os.sh"
trap 'report_error "$?" "$LINENO"' ERR

MISE_VERSION='v2026.11.9'
MISE_INSTALLER_URL="https://github.com/jdx/mise/releases/download/$MISE_VERSION/install.sh"
MISE_INSTALLER_SHA256='60adf5460b19a791b964c414a2fff9d46990c9f2b1dfc0e4ba8c2b865f882a2b'

usage() {
    printf '%s\n' \
        'Usage: bash scripts/bootstrap.sh [--help]' \
        'Install missing zsh, curl, mise, Neovim, Node, OpenCode, Zellij and Ghostty after separate confirmation.' \
        'Does not configure the shell, deploy dotfiles or upgrade software.'
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

mise_version() {
    local executable=$1 output
    output=$("$executable" --version 2>/dev/null) || return 1
    printf '%s\n' "${output%% *}"
}

installer_sha256() {
    local platform=$1 installer=$2 output
    case "$platform" in
    debian)
        command -v sha256sum >/dev/null 2>&1 ||
            return 1
        output=$(sha256sum "$installer") || return 1
        ;;
    macos)
        command -v shasum >/dev/null 2>&1 ||
            return 1
        output=$(shasum -a 256 "$installer") || return 1
        ;;
    *) return 1 ;;
    esac
    printf '%s\n' "${output%% *}"
}

ensure_mise() {
    local platform=$1 target existing version installer checksum directory
    [[ -n "${HOME:-}" && -d "$HOME" ]] ||
        die 'HOME must be an existing directory before installing mise.'
    target="$HOME/.local/bin/mise"
    existing=$(command -v mise || :)
    if [[ -n "$existing" ]]; then
        version=$(mise_version "$existing") ||
            die "Found mise at $existing but could not read its version; nothing changed."
        log "Existing mise $version at $existing; skipped installation and upgrade."
        return
    fi

    if [[ -e "$target" || -L "$target" ]]; then
        [[ -f "$target" && ! -L "$target" ]] ||
            die "Mise destination exists but is not a regular file: $target"
        version=$(mise_version "$target") ||
            die "Found mise destination at $target but could not read its version; nothing changed."
        log "Existing mise $version at $target; skipped installation and upgrade."
        return
    fi
    for directory in "$HOME/.local" "$HOME/.local/bin"; do
        if [[ -e "$directory" || -L "$directory" ]]; then
            [[ -d "$directory" && ! -L "$directory" ]] ||
                die "Mise parent path is not a regular directory: $directory"
        fi
    done

    if ! confirm "Download mise $MISE_VERSION installer from GitHub to a temporary file and verify its SHA-256?"; then
        log 'Skipped mise installer download; mise remains unavailable.'
        return
    fi
    installer=$(mktemp "${TMPDIR:-/tmp}/mise-installer.XXXXXX") ||
        die 'Could not create a temporary mise installer file.'
    if ! curl --fail --location --output "$installer" "$MISE_INSTALLER_URL"; then
        rm -f -- "$installer"
        die 'Could not download the mise installer.'
    fi
    if ! checksum=$(installer_sha256 "$platform" "$installer"); then
        rm -f -- "$installer"
        die 'Could not verify the mise installer SHA-256.'
    fi
    if [[ "$checksum" != "$MISE_INSTALLER_SHA256" ]]; then
        rm -f -- "$installer"
        die 'Mise installer SHA-256 did not match; nothing installed.'
    fi
    log "Verified mise $MISE_VERSION installer."

    if ! confirm "Install mise $MISE_VERSION at $target? This creates missing parent directories and downloads the verified release binary."; then
        rm -f -- "$installer"
        log 'Skipped mise installation after verification; no mise was installed.'
        return
    fi
    if ! MISE_VERSION="$MISE_VERSION" MISE_INSTALL_PATH="$target" \
        MISE_INSTALL_FROM_GITHUB=1 MISE_INSTALL_SKIP_IF_EXISTS=1 sh "$installer"; then
        rm -f -- "$installer"
        die 'Mise installation failed; check the installer output.'
    fi
    rm -f -- "$installer"

    version=$(mise_version "$target") ||
        die "Mise was not executable at the expected path: $target"
    [[ "$version" == "${MISE_VERSION#v}" ]] ||
        die "Mise version mismatch: expected ${MISE_VERSION#v}, found $version."
    log "Installed mise $version at $target."
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
ensure_mise "$platform"
bash "$ROOT/scripts/provision-tool.sh" neovim
bash "$ROOT/scripts/provision-tool.sh" node
bash "$ROOT/scripts/provision-tool.sh" opencode
bash "$ROOT/scripts/provision-tool.sh" zellij
bash "$ROOT/scripts/install-ghostty.sh"
log 'Bootstrap complete. Not implemented: SSH setup, other tool installation, dotfile deployment,'
log 'Git updates, or shell configuration.'
