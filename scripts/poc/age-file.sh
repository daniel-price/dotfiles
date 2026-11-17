#!/usr/bin/env bash
# POC 1B: prove mise encrypted file history without touching the real machine.
set -euo pipefail

usage() {
    printf '%s\n' 'Usage: bash scripts/poc/age-file.sh [--apply|--help]' \
        'Default: preview only; --apply runs an isolated synthetic-file experiment.' \
        'Requires git, mise with encrypted dotfile history, and age-keygen.'
}
case "${1:-}" in
-h | --help) usage; exit 0 ;;
'') [[ $# -eq 0 ]] || exit 2; mode=preview ;;
--apply) [[ $# -eq 1 ]] || exit 2; mode=apply ;;
*) usage >&2; exit 2 ;;
esac

printf '%s\n' 'POC 1B: encrypt two versions of a FAKE file in a disposable mise Git history,' \
    'inspect every reachable Git blob, verify missing-key refusal, and restore an earlier version.' \
    'No public Git repository, actual HOME, bootstrap manifest, or remote is changed.'
[[ "$mode" == apply ]] || exit 0
[[ -t 0 && -t 1 ]] || { printf '%s\n' 'Interactive terminal required.' >&2; exit 1; }
for tool in git mise age-keygen; do
    command -v "$tool" >/dev/null 2>&1 || {
        printf 'Missing prerequisite: %s\n' "$tool" >&2
        exit 1
    }
done
printf 'Create an isolated synthetic demo workspace? [y/N] '
IFS= read -r answer
[[ "$answer" == y || "$answer" == Y || "$answer" == yes ]] || {
    printf '%s\n' 'Declined; nothing created.'
    exit 0
}

# Important: isolate every mise data/config/state directory, not just HOME.
umask 077
work=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-age-file-poc.XXXXXXXX")
export HOME="$work/home"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_CACHE_HOME="$HOME/.cache"
export MISE_CONFIG_DIR="$XDG_CONFIG_HOME/mise"
export MISE_GLOBAL_CONFIG_FILE="$MISE_CONFIG_DIR/config.toml"
export MISE_DATA_DIR="$XDG_DATA_HOME/mise"
export MISE_STATE_DIR="$XDG_STATE_HOME/mise"
export MISE_CACHE_DIR="$XDG_CACHE_HOME/mise"
export MISE_AGE_KEY_FILE="$work/identity.txt"
export MISE_HISTORY_SYNC=manual
mkdir -p "$MISE_CONFIG_DIR" "$HOME/.config/poc"
age-keygen -o "$MISE_AGE_KEY_FILE" >"$work/keygen.log" 2>&1
recipient=$(sed -n 's/^# public key: //p' "$MISE_AGE_KEY_FILE")
[[ "$recipient" == age1* ]] || { printf '%s\n' 'Cannot read age recipient.' >&2; exit 1; }

# Configure encryption BEFORE the very first tracked version.
printf '[settings]\nexperimental = true\n\n[settings.history]\nsync = "manual"\n\n[history.encryption]\nrecipients = ["%s"]\n' "$recipient" >"$MISE_GLOBAL_CONFIG_FILE"
file="$HOME/.config/poc/example.conf"
printf '%s\n' 'sample=synthetic-file-poc-v1' >"$file"
mise -C "$HOME" dot track "$file" --encrypt >/dev/null
printf '%s\n' 'sample=synthetic-file-poc-v2' >"$file"
mise -C "$HOME" dot save --description 'synthetic encrypted file version two' >/dev/null

history="$MISE_STATE_DIR/history/repo.git"
[[ -d "$history" ]] || { printf '%s\n' 'Mise did not create a history repository.' >&2; exit 1; }
count=$(git --git-dir="$history" rev-list --count --all)
[[ "$count" -ge 2 ]] || { printf '%s\n' 'Expected at least two history commits.' >&2; exit 1; }

# Scan all reachable blobs, including intermediate versions, not only HEAD.
while IFS= read -r object; do
    [[ "$(git --git-dir="$history" cat-file -t "$object")" == blob ]] || continue
    if git --git-dir="$history" cat-file blob "$object" |
        LC_ALL=C grep -aEq 'synthetic-file-poc-v[12]'; then
        printf '%s\n' 'FAIL: plaintext found in reachable Git history.' >&2
        exit 1
    fi
done < <(git --git-dir="$history" rev-list --objects --all | cut -d ' ' -f 1)
printf '%s\n' 'PASS: no synthetic plaintext in any reachable Git blob.'

# Refuse to restore without the identity. The live file must stay unchanged.
export MISE_AGE_KEY_FILE="$work/missing-identity.txt"
if mise -C "$HOME" dot rollback "$file" --to latest~1 >/dev/null 2>&1; then
    printf '%s\n' 'FAIL: rollback unexpectedly succeeded without the identity.' >&2
    exit 1
fi
grep -Fxq 'sample=synthetic-file-poc-v2' "$file" || {
    printf '%s\n' 'FAIL: missing-key rollback modified the file.' >&2
    exit 1
}
export MISE_AGE_KEY_FILE="$work/identity.txt"
mise -C "$HOME" dot rollback "$file" --to latest~1 >/dev/null
grep -Fxq 'sample=synthetic-file-poc-v1' "$file" || {
    printf '%s\n' 'FAIL: rollback did not restore the first encrypted version.' >&2
    exit 1
}
printf '%s\n' 'PASS: missing key refused; correct key restored version one.'
printf 'Demo workspace: %s\n' "$work"
printf 'History (separate from public Git): %s\n' "$history"
printf 'Private disposable identity (never commit): %s\n' "$MISE_AGE_KEY_FILE"
printf '%s\n' 'See docs/guides/age-file-poc.md for second-machine recovery and cleanup.'
