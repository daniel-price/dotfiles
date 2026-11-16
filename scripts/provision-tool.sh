#!/usr/bin/env bash
set -euo pipefail

ROOT=$(CDPATH='' cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
# shellcheck source=scripts/lib/common.sh
source "$ROOT/scripts/lib/common.sh"
# shellcheck source=scripts/lib/mise.sh
source "$ROOT/scripts/lib/mise.sh"
trap 'report_error "$?" "$LINENO"' ERR

usage() {
    printf '%s\n' \
        'Usage: bash scripts/provision-tool.sh neovim' \
        'Install one declared tool with mise after confirmation.' \
        'Skips installed tools and never upgrades them.'
}

if [[ $# -ne 1 ]]; then
    die 'Expected exactly one tool name.'
fi
case "$1" in
-h | --help)
    usage
    exit 0
    ;;
neovim)
    tool=neovim
    spec='neovim@0.12.6'
    config_dir="$ROOT/.config/mise/tools"
    ;;
*)
    die 'Unsupported tool. Use --help for usage.'
    ;;
esac

if ! mise=$(mise_command); then
    log 'mise is unavailable; skipped tool provisioning.'
    exit 0
fi
trust_mise_config_dir "$config_dir"

if "$mise" -C "$config_dir" install --dry-run-code "$spec"; then
    log "$tool is already installed; skipped."
    exit 0
else
    status=$?
fi
[[ "$status" -eq 1 ]] || die "Could not determine whether $tool is installed."

if ! confirm "Install $spec with mise?"; then
    log "Skipped $tool installation; no mise command ran."
    exit 0
fi
"$mise" -C "$config_dir" install "$spec" || die "mise failed to install $spec."
"$mise" -C "$config_dir" install --dry-run-code "$spec" ||
    die "$spec is not reported installed after the mise command."
log "Installed $spec."
