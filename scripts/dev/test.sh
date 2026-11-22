#!/usr/bin/env bash
set -euo pipefail

ROOT=$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)

main() {
    bash "$ROOT/scripts/dev/test-bats.sh"
    bash "$ROOT/tests/hooks.sh"
    bash "$ROOT/tests/run.sh"
}

main "$@"
