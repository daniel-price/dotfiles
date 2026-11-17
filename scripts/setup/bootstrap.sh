#!/usr/bin/env bash
set -euo pipefail
ROOT=$(CDPATH='' cd -- "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)
# shellcheck source=scripts/lib/common.sh
source "$ROOT/scripts/lib/common.sh"
# shellcheck source=scripts/lib/os.sh
source "$ROOT/scripts/lib/os.sh"
# shellcheck source=scripts/lib/mise.sh
source "$ROOT/scripts/lib/mise.sh"
trap 'report_error "$?" "$LINENO"' ERR

MISE_VERSION='v2026.11.9'
MISE_INSTALLER_URL="https://github.com/jdx/mise/releases/download/$MISE_VERSION/install.sh"
MISE_INSTALLER_SHA256='60adf5460b19a791b964c414a2fff9d46990c9f2b1dfc0e4ba8c2b865f882a2b'

usage() {
    printf '%s\n' 'Usage: bash scripts/setup/bootstrap.sh [--help]' \
        'Install missing mise, then provision reviewed machine packages and tools.' \
        'Every missing component requires its own interactive approval.'
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

case "${1:-}" in
-h | --help)
    [[ $# -eq 1 ]] || die 'Unexpected extra argument.'
    usage
    exit 0
    ;;
'') [[ $# -eq 0 ]] || die 'Unexpected argument.' ;;
*) die 'Unknown argument. Use --help for usage.' ;;
esac

# Stage zero requires curl; it is also needed to verify and install mise.
command -v curl >/dev/null 2>&1 || die 'curl is required to download mise; install it first.'
platform=$(detect_os) || die 'Unsupported platform.'
log "Detected platform: $platform."
ensure_mise "$platform"

mise=$(mise_command) || die 'mise was not found; run bootstrap again after approving its installation.'
mise_supports_dot "$mise" || die 'mise 2026.11.9 or newer is required for native machine bootstrap.'
# Run from / so the checkout's root mise.toml (dev tooling) is never loaded.
# The single reviewed machine config is the only global config for these calls.
export MISE_GLOBAL_CONFIG_FILE="$ROOT/.config/mise/config.toml"
[[ -f "$MISE_GLOBAL_CONFIG_FILE" ]] || die 'Missing declarative machine config.'

if command -v zsh >/dev/null 2>&1 && zsh --version >/dev/null 2>&1; then
    log 'zsh is available; no package installation needed.'
else
    "$mise" -C / bootstrap --only packages --dry-run ||
        die 'Could not preview the zsh package install.'
    if confirm 'Install missing zsh using the native package manager via mise?'; then
        "$mise" -C / bootstrap --only packages || die 'mise could not install zsh.'
    else
        log 'Skipped zsh package installation.'
    fi
fi

for tool in neovim zellij; do
    # Tool pins come only from .config/mise/config.toml.
    if "$mise" -C / install --dry-run-code "$tool"; then
        log "$tool is already installed."
        continue
    else
        status=$?
    fi
    [[ "$status" -eq 1 ]] || die "Could not inspect the installed $tool version."
    if confirm "Install missing $tool from the reviewed mise machine config?"; then
        "$mise" -C / install "$tool" || die "mise could not install $tool."
    else
        log "Skipped $tool installation."
    fi
done

log 'Bootstrap complete. Dotfile deployment remains a separate opt-in action.'
