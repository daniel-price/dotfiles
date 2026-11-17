#!/usr/bin/env bash
# Shared, opt-in Podman prerequisite for isolated apps and future services.
# Mise owns the apt package declaration; this script only handles approval
# and verification. Nothing is installed during normal machine bootstrap.
set -euo pipefail

ROOT=$(CDPATH='' cd -- "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)
# shellcheck source=scripts/lib/common.sh
source "$ROOT/scripts/lib/common.sh"
# shellcheck source=scripts/lib/mise.sh
source "$ROOT/scripts/lib/mise.sh"

usage() {
    printf '%s\n' \
        'Usage: bash scripts/setup/setup-podman.sh [--apply|--dry-run|--help]' \
        'Default: inspect Podman and preview the optional apt package via mise.' \
        '--apply: offer to install missing Podman, then verify rootless mode.' \
        'Never upgrades/removes existing packages or enables system services.'
}

mode=preview
case "${1:-}" in
--help | -h)
    [[ $# -eq 1 ]] || die 'Help accepts no extra arguments.'
    usage
    exit 0
    ;;
'' | --dry-run)
    [[ $# -le 1 ]] || die 'Unexpected extra argument.'
    ;;
--apply)
    [[ $# -eq 1 ]] || die 'Unexpected extra argument.'
    mode=apply
    ;;
*) die 'Unknown argument. See --help.' ;;
esac

[[ "$(uname -s)" == Linux ]] ||
    die 'This optional Podman setup currently supports Linux only.'
[[ "$(id -u)" != 0 ]] ||
    die 'Run as your normal user, not root or via sudo.'
manifest="$ROOT/containers/podman/mise.toml"
[[ -f "$manifest" && ! -L "$manifest" ]] ||
    die 'The reviewed Podman package manifest is missing or a symlink.'

if command -v podman >/dev/null 2>&1; then
    podman --version || die 'Podman is on PATH but is not executable.'
    log 'Podman is already installed; leaving its package version unchanged.'
else
    mise=$(mise_command) ||
        die 'mise is required for declarative package setup. Run the reviewed machine bootstrap first.'
    mise_supports_dot "$mise" ||
        die 'mise 2026.11.9 or newer is required for declarative package setup.'

    # Explicit global config plus -C / prevents project or machine manifests
    # from adding other packages, tools, dotfiles or services to this operation.
    export MISE_GLOBAL_CONFIG_FILE="$manifest"
    log 'Only the declared apt:podman package is eligible for installation.'
    "$mise" -C / bootstrap --only packages --dry-run ||
        die 'mise could not preview the optional Podman package.'

    if [[ "$mode" == preview ]]; then
        log 'Preview only. Run with --apply to offer installation (default no).'
        exit 0
    fi
    if ! confirm 'Install missing Podman via the declared apt:podman package using mise?'; then
        log 'Declined Podman installation; nothing installed.'
        exit 0
    fi
    "$mise" -C / bootstrap --only packages ||
        die 'mise failed to install the declared Podman package.'
    command -v podman >/dev/null 2>&1 ||
        die 'Mise finished but Podman is unavailable on PATH.'
    podman --version || die 'Podman was installed but is not executable.'
fi

# Rootless is a runtime property; packaging alone cannot guarantee it.
rootless=$(podman info --format '{{.Host.Security.Rootless}}' 2>/dev/null) ||
    die 'Podman could not be started as this user. Review rootless setup (uidmap, subuid/subgid).'
[[ "$rootless" == true ]] ||
    die 'Podman is not running rootless. Refusing to use a rootful container runtime.'
log 'Podman is ready in rootless mode. No containers or services were started.'
