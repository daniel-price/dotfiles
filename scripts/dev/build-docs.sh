#!/usr/bin/env bash
set -euo pipefail

ROOT=$(CDPATH='' cd -- "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)
cd "$ROOT"

# Generated references are build products, never checked into Git.
trap 'rm -f "$ROOT/docs/guides/zsh.md" "$ROOT/docs/guides/zellij.md"' EXIT
python3 scripts/docs/generate.py
python3 -m zensical build --clean --strict "$@"
