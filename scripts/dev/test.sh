#!/usr/bin/env bash
set -euo pipefail
ROOT=$(CDPATH='' cd -- "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)

bash "$ROOT/scripts/dev/test-bats.sh"
bash "$ROOT/tests/hooks.sh"
bash "$ROOT/tests/run.sh"
