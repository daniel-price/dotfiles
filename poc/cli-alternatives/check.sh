#!/usr/bin/env bash
set -euo pipefail
HERE=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
bash "$HERE/getoptions/check.sh"
if [[ ${1-} == --install ]]; then
    TMP=$(mktemp -d)
    trap 'rm -rf -- "$TMP"' EXIT
    URL='https://raw.githubusercontent.com/arg-sh/argsh/2b83318b6d1a842ba8db59cad446564335502091/argsh.min.sh'
    curl -fLsS --retry 3 --max-time 30 "$URL" -o "$TMP/argsh.min.sh"
    actual=$(git hash-object "$TMP/argsh.min.sh")
    expected='0d56efa1bc3a1906dd4f087f2aa668fd3d52974e'
    [[ $actual == "$expected" ]] || {
        printf 'Argsh pinned blob mismatch! expected %s, got %s\n' "$expected" "$actual" >&2
        exit 1
    }
    export ARGSH_POC_LIB="$TMP/argsh.min.sh"
fi
if [[ -r ${ARGSH_POC_LIB:-} ]]; then
    bash "$HERE/argsh/check.sh"
else
    printf 'SKIP Argsh: set ARGSH_POC_LIB or run with --install\n'
fi
