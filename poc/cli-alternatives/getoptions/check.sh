#!/usr/bin/env bash
set -euo pipefail
HERE=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
CLI="$HERE/case-text"
JUMP="$HERE/jump-resolve"
[[ $(bash "$CLI" --case upper 'Hello World') == 'HELLO WORLD' ]]
[[ $(bash "$CLI" --case=upper 'Hello World') == 'HELLO WORLD' ]]
[[ $(bash "$CLI" --case lower 'Hello World') == 'hello world' ]]
[[ $(bash "$CLI" 'Hello World') == 'hello world' ]]
[[ $(bash "$CLI" -n --case=upper 'Hello World') == 'HELLO WORLD' ]]
[[ $(bash "$CLI" -- --help) == '--help' ]]
for args in '--case invalid Hello' '--unknown Hello' '--case' ''; do
    # shellcheck disable=SC2086
    if bash "$CLI" $args >/dev/null 2>&1; then
        echo "Unexpected success: $args" >&2
        exit 1
    fi
done
bash "$CLI" --help | grep -- '--case'
bash "$CLI" --_poc_markdown | grep 'lower|upper'
bash "$CLI" --_poc_complete '' '' | grep -- '--case'
bash "$CLI" --_poc_complete '' '--' | grep -- '--no-newline'
bash "$CLI" --_poc_complete '--case' '' | grep 'upper'
bash "$CLI" --_poc_complete '' '--case=' | grep -- '--case=upper'
TMP=$(mktemp -d)
trap 'rm -rf -- "$TMP"' EXIT
mkdir -p "$TMP/bookmark"
[[ $(CLI_POC_DEMO_ROOT="$TMP/bookmark" bash "$JUMP" demo) == "$TMP/bookmark" ]]
[[ $(bash "$JUMP" --_poc_complete '' '') == *demo* ]]
if bash "$JUMP" /nonexistent/dotfiles-poc-dir >/dev/null 2>&1; then exit 1; fi
printf 'PASS: getoptions parser, validation, Markdown and completion candidates (not interactive Tab)\n'
