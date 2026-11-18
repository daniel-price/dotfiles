#!/usr/bin/env bash
# shellcheck disable=SC2016 # literal Markdown backticks in assertion strings
set -euo pipefail
HERE=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
CLI="$HERE/bin/,case-text"
[[ "$(bash "$CLI" --case upper 'Hello World')" == 'HELLO WORLD' ]]
[[ "$(bash "$CLI" --case=lower 'Hello World')" == 'hello world' ]]
[[ "$(bash "$CLI" -n --case upper 'Hello World')" == 'HELLO WORLD' ]]
[[ "$(bash "$CLI" -- --help)" == '--help' ]]
if bash "$CLI" --case invalid Hi >/dev/null 2>&1; then
    echo 'accepted invalid choice' >&2
    exit 1
fi
if bash "$CLI" --bad Hi >/dev/null 2>&1; then
    echo 'accepted unknown flag' >&2
    exit 1
fi
if bash "$CLI" >/dev/null 2>&1; then
    echo 'accepted missing argument' >&2
    exit 1
fi
bash "$CLI" --help | grep -- '--case'
bash "$CLI" --_poc_markdown | grep -- '| `--case` |'
bash "$CLI" --_poc_complete '' '' | grep -- '--case'
bash "$CLI" --_poc_complete '' '--' | grep -- '--no-newline'
bash "$CLI" --_poc_complete '--case' '' | grep -- 'upper'
TMP=$(mktemp -d)
trap 'rm -rf -- "$TMP"' EXIT
mkdir -p "$TMP/bookmark"
[[ "$(CLI_POC_DEMO_ROOT="$TMP/bookmark" bash "$HERE/bin/,jump-demo-resolve" demo)" == "$TMP/bookmark" ]]
if bash "$HERE/bin/,jump-demo-resolve" /no/such/directory >/dev/null 2>&1; then
    echo 'accepted missing directory' >&2
    exit 1
fi
bash "$HERE/bin/,jump-demo-resolve" --_poc_markdown | grep -- '`target`'
printf 'PASS: Bash parsing, errors, help, Markdown and completion candidates (not interactive Tab)\n'
