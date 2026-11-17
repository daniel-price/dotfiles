#!/usr/bin/env bash
set -euo pipefail

ROOT=$(CDPATH='' cd -- "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)
# shellcheck source=scripts/lib/shell-files.sh
source "$ROOT/scripts/lib/shell-files.sh"

usage() {
    printf '%s\n' 'Usage: bash scripts/dev/lint.sh [-- FILE ...]' \
        'Without FILE arguments, lint all tracked *.sh files.' \
        'Linting never rewrites or stages files.'
}

case "${1:-}" in
-h | --help)
    usage
    exit 0
    ;;
--) shift ;;
-*)
    usage >&2
    exit 2
    ;;
esac

select_shell_files "$@"
if [[ ${#files[@]} -eq 0 ]]; then
    printf 'No tracked shell scripts to lint.\n'
    exit 0
fi
exec "$ROOT/scripts/dev/run-mise.sh" exec -- shellcheck -x -- "${files[@]}"
