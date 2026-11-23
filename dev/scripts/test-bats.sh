#!/usr/bin/env bash
set -euo pipefail

ROOT=$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)

main() {
    # The developer manifest pins Bats; do not require a system-wide installation.
    if [[ $# -eq 0 ]]; then
        set -- dev/tests/cli
    fi
    exec "$ROOT/dev/scripts/run-mise.sh" exec -- bats "$@"
}

main "$@"
