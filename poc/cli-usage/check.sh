#!/usr/bin/env bash
set -euo pipefail

POC_DIR=$(CDPATH='' cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
if [[ "${1:-}" != --inside ]]; then
    if ! command -v mise >/dev/null 2>&1; then
        printf 'mise is required; install mise first.\n' >&2
        exit 127
    fi
    case "${1:-}" in
    --install) mise -C "$POC_DIR" install ;;
    "") ;;
    *) printf 'Usage: bash poc/cli-usage/check.sh [--install]\n' >&2; exit 2 ;;
    esac
    exec mise -C "$POC_DIR" exec -- bash "$POC_DIR/check.sh" --inside
fi

command -v usage >/dev/null 2>&1 || {
    printf 'usage is not installed; rerun with --install.\n' >&2
    exit 127
}
CLI="$POC_DIR/bin/,case-text"
TMP=$(mktemp -d)
trap 'rm -rf -- "$TMP"' EXIT

usage lint "$CLI"
help=$("$CLI" --help)
[[ "$help" == *--case* && "$help" == *--no-newline* && "$help" == *lower* ]]
[[ "$("$CLI" --case upper "Hello World")" == "HELLO WORLD" ]]
[[ "$("$CLI" --case lower "Hello World")" == "hello world" ]]
[[ "$("$CLI" "Hello World")" == "hello world" ]]
[[ "$("$CLI" --no-newline "Hello")" == "hello" ]]
if "$CLI" --case invalid Hello >"$TMP/out" 2>"$TMP/err"; then
    printf 'Invalid choice was accepted.\n' >&2
    exit 1
fi
if "$CLI" --unknown Hello >"$TMP/out" 2>"$TMP/err"; then
    printf 'Unknown option was accepted.\n' >&2
    exit 1
fi
if "$CLI" >"$TMP/out" 2>"$TMP/err"; then
    printf 'Missing required text was accepted.\n' >&2
    exit 1
fi
usage generate markdown --file "$CLI" >"$TMP/reference.md"
usage generate completion zsh ,case-text --file "$CLI" >"$TMP/completion.zsh"
[[ -s "$TMP/reference.md" && -s "$TMP/completion.zsh" ]]
grep -q -- '--case' "$TMP/reference.md"
printf 'PASS: Usage parsed flags, validated choices and required arguments, produced help, Markdown and Zsh completion.\n'
