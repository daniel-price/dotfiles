#!/usr/bin/env bash
set -euo pipefail
ROOT=$(CDPATH='' cd -- "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)

# The developer manifest pins Bats; do not require a system-wide installation.
if [[ $# -eq 0 ]]; then
    set -- tests/cli
fi
exec "$ROOT/scripts/dev/run-mise.sh" exec -- bats "$@"
