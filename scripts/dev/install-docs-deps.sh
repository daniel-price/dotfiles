#!/usr/bin/env bash
set -euo pipefail

# Uniform entrypoint root is intentionally unused by this standalone tool install.
# shellcheck disable=SC2034
ROOT=$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)

main() {
    # Use an activated virtual environment locally; CI provisions its own Python.
    exec python3 -m pip install zensical
}

main "$@"
