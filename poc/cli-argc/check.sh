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
    *)
        printf 'Usage: bash poc/cli-argc/check.sh [--install]\n' >&2
        exit 2
        ;;
    esac
    exec mise -C "$POC_DIR" exec -- bash "$POC_DIR/check.sh" --inside
fi

command -v argc >/dev/null 2>&1 || {
    printf 'argc is not installed; rerun with --install.\n' >&2
    exit 127
}
CLI="$POC_DIR/bin/,case-text"
TMP=$(mktemp -d)
trap 'rm -rf -- "$TMP"' EXIT

help=$("$CLI" --help 2>&1)
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
mkdir -p "$TMP/man"
argc --argc-mangen "$CLI" "$TMP/man"
argc --argc-completions zsh ,case-text >"$TMP/completion.zsh"
[[ -s "$TMP/completion.zsh" ]]
[[ -n "$(find "$TMP/man" -type f -print -quit)" ]]
argc --argc-build "$CLI" "$TMP/built-case-text"
[[ "$(env PATH=/usr/bin:/bin bash "$TMP/built-case-text" --case upper "Hello World")" == "HELLO WORLD" ]]
printf 'PASS: argc parsed flags, validated choices and required arguments, produced help, man pages and Zsh completion; compiled output runs without argc.\n'
