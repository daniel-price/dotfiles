#!/usr/bin/env bash
# Opt-in reusable profile. Clone only a selected repo; never fetch automatically.
set -euo pipefail

ROOT=$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)

# shellcheck source=scripts/lib/common.sh
source "$ROOT/scripts/lib/common.sh"
# shellcheck source=scripts/lib/mise.sh
source "$ROOT/scripts/lib/mise.sh"

main() {
    local name='' repo='' apply=false deactivate=false checkout profiles_root origin tmp mise spec status specs

    usage() {
        printf '%s\n' 'Usage: bash scripts/setup/profile.sh --name NAME --repo URL [--apply]' \
            '       bash scripts/setup/profile.sh --name NAME --deactivate [--apply]' \
            'Default: preview only. --apply asks before clone, configuration and each tool install.' \
            'Supports explicitly selected GitHub HTTPS/SSH URLs or local Git paths for tests.' \
            'Never fetches, pulls, discovers repositories, or installs tools without approval.'
    }

    while [[ $# -gt 0 ]]; do
        case "$1" in
        --name)
            [[ $# -ge 2 ]] || die '--name requires a value.'
            name=$2
            shift 2
            ;;
        --repo)
            [[ $# -ge 2 ]] || die '--repo requires a value.'
            repo=$2
            shift 2
            ;;
        --apply)
            apply=true
            shift
            ;;
        --deactivate)
            deactivate=true
            shift
            ;;
        -h | --help)
            usage
            return
            ;;
        *) die 'Unknown option; see --help.' ;;
        esac
    done
    [[ "$name" =~ ^[a-z][a-z0-9-]*$ ]] || die 'Invalid profile name.'
    if [[ "$deactivate" == true ]]; then
        [[ -z "$repo" ]] || die '--deactivate does not accept --repo.'
    else
        [[ -n "$repo" ]] || die '--repo is required.'
        case "$repo" in
        https://github.com/* | git@github.com:* | /*) ;;
        *) die 'Only github.com HTTPS/SSH URLs or explicit absolute local Git paths are supported.' ;;
        esac
        case "$repo" in
        *$'\n'* | *$'\r'* | *$'\t'* | *' '*)
            die 'Repository argument contains whitespace or control characters.'
            ;;
        esac
    fi

    [[ -n "${HOME:-}" && -d "$HOME" && "$HOME" == /* && "$HOME" != / ]] ||
        die 'An existing absolute HOME is required.'
    command -v git >/dev/null 2>&1 || die 'Git is required.'
    command -v python3 >/dev/null 2>&1 || die 'Python 3.11+ is required.'
    python3 -c 'import tomllib' >/dev/null 2>&1 || die 'Python 3.11+ (tomllib) is required.'

    profiles_root="$HOME/.dotfiles-profiles"
    checkout="$profiles_root/$name"
    if [[ -L "$profiles_root" || (-e "$profiles_root" && ! -d "$profiles_root") ]]; then
        die "Profile root is not a normal directory: $profiles_root"
    fi
    if [[ -L "$checkout" || (-e "$checkout" && ! -d "$checkout") ]]; then
        die "Profile destination is not a normal directory: $checkout"
    fi

    if [[ "$deactivate" == true ]]; then
        python3 "$ROOT/scripts/setup/profile-config.py" plan-deactivate \
            "$ROOT" "$HOME" "$profiles_root" "$name" ||
            die 'Profile deactivation preview refused; no changes made.'
        if [[ "$apply" == false ]]; then
            return
        fi
        if ! confirm "Deactivate $name, remove only its owned config links, and recompute remaining profiles?"; then
            log 'Profile deactivation declined; no changes made.'
            return
        fi
        python3 "$ROOT/scripts/setup/profile-config.py" deactivate \
            "$ROOT" "$HOME" "$profiles_root" "$name" ||
            die 'Profile deactivation failed; review active profiles before retrying.'
        return
    fi

    if [[ -d "$checkout" ]]; then
        origin=$(git -C "$checkout" remote get-url origin 2>/dev/null) ||
            die "Existing profile is missing its Git origin: $checkout"
        [[ "$origin" == "$repo" ]] ||
            die "Existing profile remote differs from the selected URL; refusing to reuse it."
        log "Existing checkout retained; no automatic fetch or pull: $checkout"
    elif [[ "$apply" == false ]]; then
        log "Would clone the selected Git repository into: $checkout"
        log 'Then review pinned tools, shell scripts, app config symlinks and managed mise config.'
        log 'No network or home changes made. Add --apply to request approval.'
        return
    else
        if ! confirm "Clone the selected profile repository into $checkout?"; then
            log 'Clone declined; nothing created.'
            return
        fi
        mkdir -p "$profiles_root" || die 'Could not create profile root.'
        tmp=$(mktemp -d "$profiles_root/.profile-clone.XXXXXXXX") ||
            die 'Could not create a temporary clone directory.'
        rmdir "$tmp" || die 'Could not prepare clone destination.'
        if ! git clone -- "$repo" "$tmp"; then
            rm -rf -- "$tmp"
            die 'Git clone failed; no profile was activated.'
        fi
        if ! mv -- "$tmp" "$checkout"; then
            rm -rf -- "$tmp"
            die 'Could not place cloned repository at the selected location.'
        fi
        log "Cloned selected repository to $checkout. No files have been activated."
    fi

    python3 "$ROOT/scripts/setup/profile-config.py" plan \
        "$ROOT" "$HOME" "$profiles_root" "$name" ||
        die 'Profile preview failed; no profile settings were applied.'
    if [[ "$apply" == false ]]; then
        return
    fi
    if ! confirm "Apply the reviewed profile configuration and create only non-conflicting app config symlinks?"; then
        log 'Profile activation declined; local checkout retained unchanged.'
        return
    fi

    python3 "$ROOT/scripts/setup/profile-config.py" apply \
        "$ROOT" "$HOME" "$profiles_root" "$name" ||
        die 'Profile application failed. Inspect managed paths before retrying.'

    specs=$(python3 "$ROOT/scripts/setup/profile-config.py" tools \
        "$ROOT" "$HOME" "$profiles_root" "$name") ||
        die 'Could not enumerate approved profile tool versions.'
    if [[ -z "$specs" ]]; then
        log 'No additional profile tools to install.'
        return
    fi
    if ! mise=$(mise_command); then
        log 'Mise is unavailable; profile files are active but tools were not installed. Run ,bootstrap first.'
        return
    fi
    export MISE_GLOBAL_CONFIG_FILE="$HOME/.config/mise/dotfiles-profiles.toml"
    while IFS= read -r spec <&3; do
        [[ -n "$spec" ]] || continue
        if "$mise" -C / install --dry-run-code "$spec"; then
            log "$spec is already installed."
            continue
        else
            status=$?
        fi
        [[ "$status" -eq 1 ]] || die "Could not inspect installed tool $spec."
        if [[ "$spec" == opencode@* ]]; then
            log 'Caution: host OpenCode is NOT sandboxed. The public opencode-sandbox is safer for untrusted projects.'
        fi
        if confirm "Install missing $spec using mise (may download and execute installer code)?"; then
            "$mise" -C / install "$spec" || die "Mise installation failed for $spec."
        else
            log "Skipped optional tool $spec; its version remains declared with auto_install=false."
        fi
    done 3<<<"$specs"
}

main "$@"
