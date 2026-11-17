#!/usr/bin/env bash
# Compatibility entry point for stage-zero setup and older scripts.
# The sole provisioning implementation lives in bin/,bootstrap.
set -euo pipefail
ROOT=$(CDPATH='' cd -- "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)
case "${1:-}" in
-h | --help)
    [[ $# -eq 1 ]] || exit 2
    exec bash "$ROOT/bin/,bootstrap" --help
    ;;
'')
    [[ $# -eq 0 ]] || exit 2
    exec bash "$ROOT/bin/,bootstrap" --no-update
    ;;
*) printf '[error] Unknown argument. Use --help.\n' >&2; exit 2 ;;
esac
