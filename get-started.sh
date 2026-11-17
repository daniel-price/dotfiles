#!/usr/bin/env bash
# Stage-zero entry point for a fresh macOS or Pop!_OS machine.
# Git might not be installed yet, so we cannot start by cloning this repo.
# This file is downloaded on its own (with curl), without requiring Git,
# SSH configuration or any sibling scripts from the checkout.
# Once Git is available, it clones the public repo and separately asks
# permission before running the checkout's bin/,bootstrap.
# Existing trusted checkouts may optionally fetch/switch/fast-forward first.
# Bash 3.2+ is expected on our supported macOS and Pop!_OS installations.
set -euo pipefail
REMOTE='https://github.com/daniel-price/dotfiles.git'

info() { printf '[info] %s\n' "$*"; }
fail() {
    printf '[error] %s\n' "$*" >&2
    exit 1
}

confirm() {
    local answer
    if [[ ! -t 0 ]]; then
        info 'Declined: confirmation requires an interactive terminal.'
        return 1
    fi
    printf '%s [y/N] ' "$1" >&2
    IFS= read -r answer || return 1
    case "$answer" in
    y | Y | yes | YES | Yes) return 0 ;;
    *) return 1 ;;
    esac
}

platform() {
    case "$(uname -s)" in
    Darwin) printf 'macos\n' ;;
    Linux)
        local release
        for release in /etc/os-release /usr/lib/os-release; do
            [[ -r "$release" ]] || continue
            if grep -Eq '^ID="?((debian|ubuntu|pop))"?$' "$release" ||
                grep -Eq '^ID_LIKE=.*(debian|ubuntu)' "$release"; then
                printf 'debian\n'
                return
            fi
            break
        done
        fail 'Unsupported Linux distribution (requires Debian/Ubuntu/Pop!_OS).'
        ;;
    *) fail 'Unsupported OS (requires macOS or Debian/Ubuntu-derived Linux).' ;;
    esac
}

git_ready() {
    command -v git >/dev/null 2>&1 && git --version >/dev/null 2>&1
}

ensure_git() {
    local os=$1
    if git_ready; then
        info 'Git is available; no installation needed.'
        return
    fi
    if [[ "$os" == macos ]]; then
        command -v xcode-select >/dev/null 2>&1 ||
            fail 'Git missing and macOS Command Line Tools installer unavailable.'
        confirm 'Request Apple Command Line Tools installation (includes Git)?' ||
            fail 'Git setup declined.'
        xcode-select --install ||
            fail 'Could not request Command Line Tools. Check for an existing installer.'
        fail 'Finish the macOS installation dialog, then rerun the script.'
    fi

    command -v apt-get >/dev/null 2>&1 || fail 'Git missing and apt-get unavailable.'
    if [[ "$(id -u)" -eq 0 ]]; then
        confirm 'Run apt-get install git (no package upgrades requested)?' ||
            fail 'Git setup declined.'
        apt-get install git || fail 'Git install failed; check apt package indexes.'
    else
        command -v sudo >/dev/null 2>&1 || fail 'Git install requires sudo.'
        confirm 'Run sudo apt-get install git (no package upgrades requested)?' ||
            fail 'Git setup declined.'
        sudo apt-get install git || fail 'Git install failed; check apt package indexes.'
    fi
    git_ready || fail 'Git is still unavailable after installation.'
}

checkout_once() {
    local target=$1 existing_origin top resolved_target resolved_top
    if [[ -e "$target" || -L "$target" ]]; then
        [[ -d "$target" && ! -L "$target" ]] ||
            fail "Checkout destination already exists as a file or symlink: $target"
        top=$(git -C "$target" rev-parse --show-toplevel 2>/dev/null || :)
        [[ -n "$top" ]] ||
            fail "Checkout destination is not a Git repository: $target"
        # On macOS, /var may be an alias of /private/var. Compare physical
        # directories, while still rejecting a nested or unrelated checkout.
        resolved_target=$(cd "$target" && pwd -P) ||
            fail "Could not resolve checkout destination: $target"
        resolved_top=$(cd "$top" && pwd -P) ||
            fail "Could not resolve Git repository root: $top"
        [[ "$resolved_top" == "$resolved_target" ]] ||
            fail "Checkout destination is not its own Git repository: $target"
        existing_origin=$(git -C "$target" remote get-url origin 2>/dev/null || :)
        case "$existing_origin" in
        "$REMOTE" | 'https://github.com/daniel-price/dotfiles' | 'git@github.com:daniel-price/dotfiles.git')
            info "Existing checkout at $target; skipped clone."
            CHECKOUT_REUSED=1
            return
            ;;
        *) fail 'Existing checkout has an unexpected origin; nothing changed.' ;;
        esac
    fi
    if ! confirm "Clone the public dotfiles repo over HTTPS to $target?"; then
        info 'Clone declined; no checkout created.'
        return
    fi
    git clone -- "$REMOTE" "$target" || fail 'Clone failed; check network and destination.'
    info "Cloned into $target."
}

main() {
    [[ $# -le 1 ]] || fail 'Expected no arguments or --help.'
    case "${1:-}" in
    -h | --help)
        printf '%s\n' 'Usage: bash dotfiles-get-started.sh [--help]' \
            'Standalone Git prerequisite, one HTTPS clone, optional guarded update and approved bootstrap handoff.'
        return
        ;;
    '') ;;
    *) fail 'Unknown argument. Use --help.' ;;
    esac
    [[ -n "${HOME:-}" && -d "$HOME" ]] || fail 'HOME must be an existing directory.'
    local os
    os=$(platform)
    info "Detected $os."
    ensure_git "$os"
    local target="$HOME/.dotfiles"
    CHECKOUT_REUSED=0
    checkout_once "$target"
    if [[ ! -d "$target" ]]; then
        info 'No checkout available; bootstrap not run.'
        return
    fi
    # Run the updater from the existing checkout before resolving bootstrap's
    # path; a successful update may replace that script with newer code.
    # Older checkouts remain supported, but cannot safely self-update without
    # an already-reviewed updater; never download and execute a remote script.
    if [[ "$CHECKOUT_REUSED" == 1 ]]; then
        updater="$target/scripts/setup/update.sh"
        if [[ -f "$updater" && ! -L "$updater" ]]; then
            info 'Checking existing checkout; updates require separate approval.'
            bash "$updater" --apply || fail 'Checkout update check failed.'
        else
            info 'Existing checkout has no reviewed updater; using the current checkout.'
            info 'Update manually when ready, then rerun to enable safe update offers.'
        fi
    fi
    local bootstrap='bin/,bootstrap'
    if [[ ! -f "$target/$bootstrap" || -L "$target/$bootstrap" ]]; then
        fail "Missing or non-regular bootstrap script at $target/$bootstrap; nothing executed."
    fi
    if ! confirm "Run the checkout bootstrap at $target/$bootstrap?"; then
        info 'Bootstrap execution declined; checkout left unchanged.'
        return
    fi
    info "Running bootstrap from $target."
    # Subshell leaves the original working directory unchanged.
    (cd "$target" && bash "./$bootstrap" --no-update) || fail 'Checkout bootstrap failed.'
}
main "$@"
