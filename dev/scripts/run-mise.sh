#!/usr/bin/env bash
set -euo pipefail

ROOT=$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)

# shellcheck source=lib/mise.sh
source "$ROOT/lib/mise.sh"

main() {
    mise=$(mise_command) || {
        printf '[error] mise is unavailable on PATH or at ~/.local/bin/mise; run machine bootstrap first.\n' >&2
        exit 1
    }
    # Tasks and tool installation use the dev project; executable tools operate
    # from the checkout root so Git-relative file arguments remain valid.
    case "${1:-}" in
    run | trust | install) cd "$ROOT/dev" ;;
    *)
        cd "$ROOT"
        export MISE_GLOBAL_CONFIG_FILE="$ROOT/dev/mise.toml"
        ;;
    esac
    exec "$mise" "$@"
}

main "$@"
