#!/usr/bin/env bash
# POC 1B: prove mise encrypted file history without touching the real machine.
set -euo pipefail
ROOT=$(CDPATH='' cd -- "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)

usage() {
    printf '%s\n' 'Usage: bash scripts/poc/age-file.sh [--apply|--help]' \
        'Default: preview only; --apply runs an isolated synthetic-file experiment.' \
        'Requires git and mise; offers pinned age if age-keygen is missing.'
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
for tool in git mise; do
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

# Reuse POC 1A's reviewed, separately approved age installation.
# This runs BEFORE isolating mise's directories, so the pinned tool can be found.
age_keygen=(age-keygen)
if ! command -v age-keygen >/dev/null 2>&1; then
    manifest="$ROOT/scripts/poc/age-tools.toml"
    [[ -f "$manifest" && ! -L "$manifest" ]] || {
        printf '%s\n' 'Missing reviewed age POC tool manifest.' >&2
        exit 1
    }
    mise_bin=$(command -v mise)
    if MISE_GLOBAL_CONFIG_FILE="$manifest" "$mise_bin" -C / install --dry-run-code age@1.3.2; then
        printf '%s\n' 'Pinned age@1.3.2 is already installed through mise.'
    else
        result=$?
        [[ "$result" -eq 1 ]] || {
            printf '%s\n' 'Unable to inspect mise age installation status.' >&2
            exit 1
        }
        printf 'Install pinned age@1.3.2 through mise for this POC? [y/N] '
        IFS= read -r install_answer
        if [[ "$install_answer" != y && "$install_answer" != Y && "$install_answer" != yes ]]; then
            printf '%s\n' 'Declined; age was not installed and no demo files were created.'
            exit 0
        fi
        MISE_GLOBAL_CONFIG_FILE="$manifest" "$mise_bin" -C / install age@1.3.2
    fi
    age_keygen=(env "MISE_GLOBAL_CONFIG_FILE=$manifest" "$mise_bin" -C / exec -- age-keygen)
fi

# Important: isolate every mise data/config/state directory, not just HOME.
umask 077
work=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-age-file-poc.XXXXXXXX")
# Generate the identity while the POC tool manifest is still accessible.
"${age_keygen[@]}" -o "$work/identity.txt" >"$work/keygen.log" 2>&1
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

# Publish the disposable history to a local bare origin, then adopt it from
# independent, empty homes. The private identity is NEVER sent to this origin.
# The global mise configuration (including the public recipient and tracking
# declarations) must be enrolled so adoption knows which file to restore.
mise -C "$HOME" dot track "$MISE_CONFIG_DIR" >/dev/null
mise -C "$HOME" dot save --description 'synthetic config enrollment for recovery' >/dev/null
origin="$work/setup-origin.git"
git init --bare -q "$origin"
# Git transport is local and explicit, not an automatic mise origin/watcher.
git --git-dir="$history" push -q "$origin" refs/heads/main:refs/heads/main

# Git never carries the private identity or the synthetic plaintext.
if git --git-dir="$origin" rev-list --objects --all |
    grep -Fq 'identity.txt'; then
    printf '%s\n' 'FAIL: private identity appeared in the origin.' >&2
    exit 1
fi
while IFS= read -r object; do
    [[ "$(git --git-dir="$origin" cat-file -t "$object")" == blob ]] || continue
    if git --git-dir="$origin" cat-file blob "$object" |
        LC_ALL=C grep -aEq 'synthetic-file-poc-v[12]|AGE-SECRET-KEY-'; then
        printf '%s\n' 'FAIL: private data appeared in the origin.' >&2
        exit 1
    fi
done < <(git --git-dir="$origin" rev-list --objects --all | cut -d ' ' -f 1)

# Each invocation uses a distinct HOME, XDG tree, mise state and cache.
# Disable global inherited configuration and installations via explicit paths.
adopt_in_fresh_home() (
    name=$1
    identity=$2
    fresh="$work/$name"
    export HOME="$fresh/home"
    export XDG_CONFIG_HOME="$HOME/.config"
    export XDG_DATA_HOME="$HOME/.local/share"
    export XDG_STATE_HOME="$HOME/.local/state"
    export XDG_CACHE_HOME="$HOME/.cache"
    export MISE_CONFIG_DIR="$XDG_CONFIG_HOME/mise"
    export MISE_GLOBAL_CONFIG_FILE="$MISE_CONFIG_DIR/config.toml"
    export MISE_DATA_DIR="$XDG_DATA_HOME/mise"
    export MISE_STATE_DIR="$XDG_STATE_HOME/mise"
    export MISE_CACHE_DIR="$XDG_CACHE_HOME/mise"
    export MISE_AGE_KEY_FILE="$identity"
    export MISE_HISTORY_SYNC=manual
    mkdir -p "$HOME"
    # Adopt only from our self-created local origin (no network remote).
    mise -C "$HOME" bootstrap --adopt "$origin" --yes >"$fresh-adopt.log" 2>&1
)
if adopt_in_fresh_home recovery-no-key "$work/nonexistent-identity"; then
    printf '%s\n' 'FAIL: clean home unexpectedly adopted encrypted file without identity.' >&2
    exit 1
fi
[[ ! -e "$work/recovery-no-key/home/.config/poc/example.conf" ]] || {
    printf '%s\n' 'FAIL: missing-key adoption wrote a plaintext target.' >&2
    exit 1
}
if ! adopt_in_fresh_home recovery-with-key "$work/identity.txt"; then
    printf 'FAIL: keyed fresh-home adoption failed; see %s\n' "$work/recovery-with-key-adopt.log" >&2
    exit 1
fi
grep -Fxq 'sample=synthetic-file-poc-v1' \
    "$work/recovery-with-key/home/.config/poc/example.conf" || {
    printf '%s\n' 'FAIL: fresh-home restoration produced unexpected contents.' >&2
    exit 1
}
printf '%s\n' 'PASS: separate clean homes refused missing key and restored with the correct identity.'

printf 'Demo workspace: %s\n' "$work"
printf 'History (separate from public Git): %s\n' "$history"
printf 'Private disposable identity (never commit): %s\n' "$MISE_AGE_KEY_FILE"
printf '%s\n' 'See docs/guides/age-file-poc.md for second-machine recovery and cleanup.'
