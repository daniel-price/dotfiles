#!/usr/bin/env bash
set -euo pipefail

ROOT=$(CDPATH='' cd -- "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)
# shellcheck source=scripts/lib/mise.sh
source "$ROOT/scripts/lib/mise.sh"
mise=$(mise_command) || {
    printf '[error] mise is unavailable on PATH or at ~/.local/bin/mise; run machine bootstrap first.\n' >&2
    exit 1
}
cd "$ROOT"
exec "$mise" "$@"
