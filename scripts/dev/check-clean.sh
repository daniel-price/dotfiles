#!/usr/bin/env bash
set -euo pipefail

ROOT=$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)

main() {
    cd "$ROOT"
    git diff --exit-code
    git diff --cached --exit-code
}

main "$@"
