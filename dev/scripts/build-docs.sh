#!/usr/bin/env bash
set -euo pipefail

ROOT=$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)

main() {
    cd "$ROOT"

    # Generated references are build products, never checked into Git.
    trap 'rm -f "$ROOT/docs/guides/zsh.md" "$ROOT/docs/guides/zellij.md" "$ROOT/docs/guides/tools.md" "$ROOT/docs/guides/cli.md" "$ROOT/docs/guides/argc.md"' EXIT
    "$ROOT/dev/scripts/run-mise.sh" exec -- python3 dev/generators/generate.py
    python3 -m zensical build --config-file dev/zensical.toml --clean --strict "$@"
}

main "$@"
