#!/usr/bin/env bash
set -euo pipefail

ROOT=$(CDPATH='' cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
cd "$ROOT"
exec python3 -m zensical build --clean --strict "$@"
