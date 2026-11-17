#!/usr/bin/env bash
set -euo pipefail

ROOT=$(CDPATH='' cd -- "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)
# shellcheck source=scripts/lib/shell-files.sh
source "$ROOT/scripts/lib/shell-files.sh"

usage() {
    printf '%s\n' 'Usage: bash scripts/dev/format.sh [--check] [-- FILE ...]' \
        'Without FILE arguments, format all tracked *.sh files.' \
        '--check reports differences without rewriting or staging files.'
}

mode=-w
while [[ $# -gt 0 ]]; do
    case "$1" in
    --check) mode=-d ;;
    -h | --help)
        usage
        exit 0
        ;;
    --)
        shift
        break
        ;;
    -*)
        usage >&2
        exit 2
        ;;
    *) break ;;
    esac
    shift
done

select_shell_files "$@"
if [[ ${#files[@]} -eq 0 ]]; then
    printf 'No tracked shell scripts to format.\n'
    exit 0
fi
exec "$ROOT/scripts/dev/run-mise.sh" exec -- shfmt "$mode" -i 4 -- "${files[@]}"
