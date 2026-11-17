#!/usr/bin/env bash
set -euo pipefail
ROOT=$(CDPATH='' cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
for command in ,curltime ,untilFailure ,repeat; do
    [[ -x "$ROOT/bin/$command" ]] || { printf 'Not executable: %s\n' "$command" >&2; exit 1; }
    bash -n "$ROOT/bin/$command"
    if "$ROOT/bin/$command" >"$tmp/out" 2>"$tmp/err"; then
        printf 'Missing args accepted: %s\n' "$command" >&2; exit 1
    fi
done
[[ "$("$ROOT/bin/,repeat" 2 bash -c 'printf x')" == *'2 succeeded; 0 failed'* ]] || exit 1
if "$ROOT/bin/,repeat" 2 bash -c 'exit 3' >"$tmp/out" 2>"$tmp/err"; then
    printf 'Repeat did not propagate failure\n' >&2; exit 1
fi
grep -q '0 succeeded; 2 failed' "$tmp/out"
if "$ROOT/bin/,untilFailure" bash -c 'exit 7' >"$tmp/out" 2>"$tmp/err"; then
    printf 'untilFailure ignored command failure\n' >&2; exit 1
else
    [[ $? -eq 7 ]] || exit 1
fi
grep -q 'after 0 successful' "$tmp/err"
printf 'PASS: portable utility scripts\n'
