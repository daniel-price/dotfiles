#!/usr/bin/env bash
set -euo pipefail

ROOT=$(CDPATH='' cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
cd "$ROOT"
# Explicit setup shared by CI and developers; mise.toml owns the versions.
exec mise install
