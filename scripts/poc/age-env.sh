#!/usr/bin/env bash
# Isolated POC: age-encrypted mise environment value (synthetic data only).
set -euo pipefail

usage() {
    printf '%s\n' 'Usage: bash scripts/poc/age-env.sh [--apply|--help]' \
        'Default: show the proposed experiment; do not create files.' \
        '--apply: create a disposable directory with a synthetic encrypted value.' \
        'Requires mise with age-value support and age-keygen; never uses real credentials.'
}
case "${1:-}" in
-h | --help)
    usage
    exit 0
    ;;
'')
    [[ $# -eq 0 ]] || exit 2
    mode=preview
    ;;
--apply)
    [[ $# -eq 1 ]] || exit 2
    mode=apply
    ;;
*)
    usage >&2
    exit 2
    ;;
esac

printf '%s\n' 'POC: generate a new age identity in a temporary directory, encrypt a FAKE value with mise,' \
    'test injection, reject a missing key, and document how to restore on another machine.' \
    'No machine manifest, login shell, Git configuration, or bootstrap files are changed.'
[[ "$mode" == apply ]] || exit 0
[[ -t 0 && -t 1 ]] || {
    printf '%s\n' 'Interactive terminal required.' >&2
    exit 1
}
command -v mise >/dev/null 2>&1 || {
    printf '%s\n' 'Missing mise.' >&2
    exit 1
}
command -v age-keygen >/dev/null 2>&1 || {
    printf '%s\n' 'Missing age-keygen (age package).' >&2
    exit 1
}
printf 'Create an isolated synthetic demo directory? [y/N] '
IFS= read -r answer
[[ "$answer" == y || "$answer" == Y || "$answer" == yes ]] || {
    printf '%s\n' 'Declined; nothing created.'
    exit 0
}

umask 077
work=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-age-poc.XXXXXXXX")
printf '[settings]\nexperimental = true\n' >"$work/mise.toml"
age-keygen -o "$work/identity.txt" >"$work/keygen.log" 2>&1 || {
    printf '%s\n' 'age-keygen failed; inspect/remove the temporary workspace.' >&2
    exit 1
}
recipient=$(sed -n 's/^# public key: //p' "$work/identity.txt")
[[ "$recipient" == age1* ]] || {
    printf '%s\n' 'Could not read the generated age recipient.' >&2
    exit 1
}
# The value is deliberately public, but its storage exercises real age encryption.
# Use -C to isolate mise config resolution from the caller's dotfiles checkout.
MISE_AGE_KEY_FILE="$work/identity.txt" mise -C "$work" set \
    --age-encrypt --age-recipient "$recipient" POC_TOKEN=synthetic-demo-only >/dev/null
MISE_AGE_KEY_FILE="$work/identity.txt" mise -C "$work" exec -- printenv POC_TOKEN | \
    grep -Fxq 'synthetic-demo-only' || {
    printf '%s\n' 'Decryption failed with the correct identity.' >&2
    exit 1
}
if MISE_AGE_KEY_FILE="$work/does-not-exist" mise -C "$work" exec -- \
    printenv POC_TOKEN >/dev/null 2>&1; then
    printf '%s\n' 'ERROR: missing-key execution unexpectedly succeeded.' >&2
    exit 1
fi
# Never print the decrypted value or the private identity.
printf 'PASS: encrypted value works with the key and fails without it.\n'
printf 'Demo workspace: %s\n' "$work"
printf 'Encrypted config: %s/mise.toml\n' "$work"
printf 'Private identity (do NOT commit): %s/identity.txt\n' "$work"
printf '%s\n' 'See docs/guides/age-env-poc.md for recovery and history checks.'
