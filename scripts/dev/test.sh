#!/usr/bin/env bash
set -euo pipefail

ROOT=$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)

main() {
    bash "$ROOT/scripts/dev/test-bats.sh"
    bash "$ROOT/tests/hooks.sh"
    bash "$ROOT/tests/run.sh"
    if command -v python3 >/dev/null 2>&1; then
        python3 "$ROOT/tests/profile-real-repos.py"
    else
        printf '%s\n' 'SKIP: real profile POC test (python3 not available)'
    fi
}

main "$@"
