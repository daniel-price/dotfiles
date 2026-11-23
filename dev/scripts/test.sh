#!/usr/bin/env bash
set -euo pipefail

ROOT=$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)

main() {
    bash "$ROOT/dev/scripts/test-bats.sh"
    bash "$ROOT/dev/tests/hooks.sh"
    # Runtime commands such as ,uuid need the pinned dev binaries on PATH.
    "$ROOT/dev/scripts/run-mise.sh" exec -- bash "$ROOT/dev/tests/run.sh"
}

main "$@"
