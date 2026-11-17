#!/usr/bin/env bash
# Single entry point: select an explicitly supported keyboard implementation.
set -euo pipefail
ROOT=$(CDPATH='' cd -- "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)
# shellcheck source=scripts/lib/common.sh
source "$ROOT/scripts/lib/common.sh"

[[ "${1:-}" == --apply && $# -eq 1 ]] ||
    die 'Usage: bash scripts/setup/keyboard.sh --apply'

case "$(uname -s)" in
Darwin) strategy=macos ;;
Linux)
    case "${XDG_CURRENT_DESKTOP:-}" in
    *COSMIC* | *cosmic*) strategy=cosmic ;;
    *)
        log "Caps Lock mapping skipped: unsupported or unrecognised desktop (${XDG_CURRENT_DESKTOP:-none})."
        exit 0
        ;;
    esac
    ;;
*)
    log 'Caps Lock remapping skipped: unsupported operating system.'
    exit 0
    ;;
esac

# No environment-derived path is executable; every strategy is allowlisted.
bash "$ROOT/scripts/platforms/keyboard/$strategy.sh" --apply
