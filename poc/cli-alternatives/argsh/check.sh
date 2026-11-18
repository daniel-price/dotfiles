#!/usr/bin/env bash
set -euo pipefail
HERE=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
LIB=${ARGSH_POC_LIB:-}
if [[ ${1-} == --install ]]; then
  [[ -n $LIB ]] || { printf 'Error: ARGSH_POC_LIB must be set by parent test runner\n' >&2; exit 2; }
fi
[[ -r $LIB ]] || { printf 'Error: set ARGSH_POC_LIB to pinned downloaded library\n' >&2; exit 2; }
if (( BASH_VERSINFO[0] < 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] < 3) )); then
  printf 'UNSUPPORTED: Argsh requires Bash 4.3+ for namerefs/associative arrays; detected %s\n' "$BASH_VERSION"
  exit 0
fi
CLI=$HERE/case-text
[[ $(bash "$CLI" --case upper 'Hello World') == 'HELLO WORLD' ]]
[[ $(bash "$CLI" --case=upper 'Hello World') == 'HELLO WORLD' ]]
[[ $(bash "$CLI" --case lower 'Hello World') == 'hello world' ]]
[[ $(bash "$CLI" 'Hello World') == 'hello world' ]]
[[ $(bash "$CLI" --no-newline 'Hello World') == 'hello world' ]]
if bash "$CLI" --case invalid Hello >/dev/null 2>&1; then echo 'invalid choice accepted' >&2; exit 1; fi
if bash "$CLI" --bad Hello >/dev/null 2>&1; then echo 'unknown flag accepted' >&2; exit 1; fi
if bash "$CLI" >/dev/null 2>&1; then echo 'missing positional accepted' >&2; exit 1; fi
bash "$CLI" --help | grep -- '--case'
# Capability probes: record actual success or failure; unsupported != passing.
for entry in 'completion zsh' 'docgen md' 'docgen man'; do
  read -r command format <<< "$entry"
  if output=$(bash "$HERE/usage-probe" "$command" "$format" 2>&1); then
    printf 'SUPPORTED: %s %s (bytes=%d)\n' "$command" "$format" "${#output}"
  else
    printf 'UNAVAILABLE: %s %s (exit=%d): %s\n' "$command" "$format" "$?" "${output:0:170}"
  fi
done
printf 'PASS: Argsh basic Bash CLI tests (documentation/completion capability probes above)\n'
