#!/usr/bin/env bash
# gnome implementation for persistent Caps Lock -> Ctrl remapping.
set -euo pipefail
ROOT=$(CDPATH='' cd -- "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)
# shellcheck source=scripts/lib/common.sh
source "$ROOT/scripts/lib/common.sh"

[[ "${1:-}" == --apply && $# -eq 1 ]] ||
    die 'Usage: bash scripts/platforms/keyboard/gnome.sh --apply'

if ! command -v gsettings >/dev/null 2>&1 ||
    ! gsettings writable org.gnome.desktop.input-sources xkb-options | grep -qx true; then
    log 'GNOME input-source settings unavailable; Caps Lock remapping skipped.'
    exit 0
fi
current=$(gsettings get org.gnome.desktop.input-sources xkb-options)
case "$current" in
*"'ctrl:nocaps'"*)
    log 'GNOME Caps Lock is already mapped to Ctrl.'
    exit 0
    ;;
esac
# Only handle the standard GVariant string-array format; preserve
# unrelated options and refuse to override conflicting mappings.
if [[ "$current" == '@as []' || "$current" == '[]' ]]; then
    desired="['ctrl:nocaps']"
elif [[ "$current" == \[*\] ]]; then
    if [[ "$current" == *"'ctrl:"* || "$current" == *"'caps:"* ]]; then
        log 'GNOME already has a Caps/Ctrl XKB option; leaving it unchanged.'
        exit 0
    fi
    desired="${current%]}, 'ctrl:nocaps']"
else
    log 'Unexpected GNOME XKB setting format; no changes made.'
    exit 0
fi
if confirm 'Set Caps Lock to act as an additional Ctrl key in GNOME keyboard settings?'; then
    gsettings set org.gnome.desktop.input-sources xkb-options "$desired"
    log 'Saved GNOME Caps Lock mapping.'
fi
