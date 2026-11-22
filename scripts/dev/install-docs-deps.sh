#!/usr/bin/env bash
set -euo pipefail

ROOT=$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)

main() {
    # Use an activated virtual environment locally; CI provisions its own Python.
    exec python3 -m pip install zensical
}

main "$@"
