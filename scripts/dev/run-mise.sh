#!/usr/bin/env bash
set -euo pipefail

ROOT=$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)

# shellcheck source=scripts/lib/mise.sh
source "$ROOT/scripts/lib/mise.sh"

main() {
    mise=$(mise_command) || {
        printf '[error] mise is unavailable on PATH or at ~/.local/bin/mise; run machine bootstrap first.\n' >&2
        exit 1
    }
    cd "$ROOT"
    exec "$mise" "$@"
}

main "$@"
