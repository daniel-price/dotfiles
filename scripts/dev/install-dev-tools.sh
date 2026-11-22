#!/usr/bin/env bash
set -euo pipefail

ROOT=$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)

main() {
    # Explicit developer setup shared by CI. The repo's trusted mise.toml owns
    # versions; enabling Git hooks is separate and requires terminal confirmation.
    "$ROOT/scripts/dev/run-mise.sh" install
    if [[ -t 0 ]]; then
        bash "$ROOT/scripts/dev/install-hooks.sh"
    else
        printf '[info] Skipping optional Git-hook setup (noninteractive stdin).\n'
    fi
}

main "$@"
