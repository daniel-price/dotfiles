#!/usr/bin/env bash
set -euo pipefail

ROOT=$(CDPATH='' cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)

usage() {
    printf '%s\n' 'Usage: bash scripts/shell.sh [check|format|lint] [-- FILE ...]' \
        'Without FILE arguments, select all tracked *.sh files.' \
        'check is read-only; format rewrites files without staging them.'
}

mode=${1:-check}
case "$mode" in
-h | --help)
    usage
    exit 0
    ;;
check | format | lint) ;;
*)
    usage >&2
    exit 2
    ;;
esac
if [[ $# -gt 0 ]]; then shift; fi
if [[ "${1:-}" == -- ]]; then shift; fi

cd "$ROOT"
files=("$@")
if [[ ${#files[@]} -eq 0 ]]; then
    git rev-parse --is-inside-work-tree >/dev/null
    while IFS= read -r -d '' file; do
        files+=("$file")
    done < <(git ls-files -z -- '*.sh')
fi
if [[ ${#files[@]} -eq 0 ]]; then
    printf 'No tracked shell scripts to check.\n'
    exit 0
fi

case "$mode" in
check)
    result=0
    mise exec -- shfmt -d -i 4 -- "${files[@]}" || result=$?
    mise exec -- shellcheck -- "${files[@]}" || result=$?
    exit "$result"
    ;;
format) exec mise exec -- shfmt -w -i 4 -- "${files[@]}" ;;
lint) exec mise exec -- shellcheck -- "${files[@]}" ;;
esac
