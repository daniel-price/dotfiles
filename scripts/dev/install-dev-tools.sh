#!/usr/bin/env bash
set -euo pipefail

ROOT=$(CDPATH='' cd -- "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)
# Explicit developer setup shared by CI. The repo's trusted mise.toml owns
# versions; enabling Git hooks is separate and requires terminal confirmation.
"$ROOT/scripts/dev/run-mise.sh" install
if [[ -t 0 ]]; then
    bash "$ROOT/scripts/dev/install-hooks.sh"
else
    printf '[info] Skipping optional Git-hook setup (noninteractive stdin).\n'
fi
