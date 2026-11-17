#!/usr/bin/env bash
set -euo pipefail
ROOT=$(CDPATH='' cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
TMP=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-stage-zero.XXXXXX")
trap 'rm -rf -- "$TMP"' EXIT
fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

bash -n "$ROOT/get-started.sh"
bash "$ROOT/get-started.sh" --help | grep -q 'Standalone Git prerequisite' ||
    fail 'help unavailable'
if bash "$ROOT/get-started.sh" --unknown >/dev/null 2>&1; then
    fail 'unknown argument accepted'
fi

mkdir "$TMP/home" "$TMP/bin"
cat >"$TMP/bin/git" <<'GIT'
#!/usr/bin/env bash
case "$1" in
    --version)
        [[ "${SIMULATE_NO_GIT:-0}" != 1 ]] || exit 1
        printf 'git version fake\n'
        ;;
    -C)
        case "$3" in
            rev-parse) printf '%s\n' "$2" ;;
            remote) printf '%s\n' "${SIMULATE_REMOTE:-https://github.com/daniel-price/dotfiles.git}" ;;
            *) exit 4 ;;
        esac
        ;;
    clone)
        printf 'UNEXPECTED CLONE\n' >&2
        exit 5
        ;;
    *) exit 6 ;;
esac
GIT
chmod +x "$TMP/bin/git"

# Piped answers must not authorise a checkout.
printf 'yes\n' | HOME="$TMP/home" PATH="$TMP/bin:$PATH" \
    bash "$ROOT/get-started.sh" >"$TMP/out" 2>&1
grep -q 'Clone declined' "$TMP/out" || fail 'noninteractive clone not declined'
[[ ! -e "$TMP/home/.dotfiles" ]] || fail 'checkout created without consent'

# Existing checkout with exact origin should be skipped without changing it.
mkdir -p "$TMP/home/.dotfiles/scripts/setup"
cat >"$TMP/home/.dotfiles/scripts/setup/bootstrap.sh" <<'BOOT'
#!/usr/bin/env bash
printf 'unexpected bootstrap execution\n' > "$HOME/bootstrap-invoked"
BOOT
HOME="$TMP/home" PATH="$TMP/bin:$PATH" \
    bash "$ROOT/get-started.sh" >"$TMP/out" 2>&1
grep -q 'skipped clone and update' "$TMP/out" || fail 'existing clone not skipped'
grep -q 'Bootstrap execution declined' "$TMP/out" || fail 'bootstrap should require a separate approval'
[[ ! -e "$TMP/home/bootstrap-invoked" ]] || fail 'bootstrap executed without terminal approval'

if HOME="$TMP/home" SIMULATE_REMOTE='https://example.invalid/other' \
    PATH="$TMP/bin:$PATH" bash "$ROOT/get-started.sh" >"$TMP/out" 2>&1; then
    fail 'unrecognised origin accepted'
fi
grep -q 'unexpected origin' "$TMP/out" || fail 'missing origin error'

# Previous checkouts stored bootstrap directly under scripts/.
mv "$TMP/home/.dotfiles/scripts/setup/bootstrap.sh" "$TMP/home/.dotfiles/scripts/bootstrap.sh"
rmdir "$TMP/home/.dotfiles/scripts/setup"
HOME="$TMP/home" PATH="$TMP/bin:$PATH" \
    bash "$ROOT/get-started.sh" >"$TMP/out" 2>&1
grep -q 'Bootstrap execution declined' "$TMP/out" || fail 'previous bootstrap approval was not requested'
[[ ! -e "$TMP/home/bootstrap-invoked" ]] || fail 'previous bootstrap ran without approval'

# Even older checkouts used a root-level bootstrap.
mv "$TMP/home/.dotfiles/scripts/bootstrap.sh" "$TMP/home/.dotfiles/bootstrap.sh"
rmdir "$TMP/home/.dotfiles/scripts"
HOME="$TMP/home" PATH="$TMP/bin:$PATH" \
    bash "$ROOT/get-started.sh" >"$TMP/out" 2>&1
grep -q 'Bootstrap execution declined' "$TMP/out" || fail 'root bootstrap approval was not requested'
[[ ! -e "$TMP/home/bootstrap-invoked" ]] || fail 'root bootstrap ran without approval'
rm "$TMP/home/.dotfiles/bootstrap.sh"
rmdir "$TMP/home/.dotfiles"
printf 'untouched\n' >"$TMP/home/.dotfiles"
if HOME="$TMP/home" PATH="$TMP/bin:$PATH" \
    bash "$ROOT/get-started.sh" >"$TMP/out" 2>&1; then
    fail 'existing file accepted'
fi
[[ "$(cat "$TMP/home/.dotfiles")" == untouched ]] || fail 'conflict overwritten'
rm "$TMP/home/.dotfiles"

# A noninteractive install must never succeed, whether on macOS or Linux.
if printf 'yes\n' | HOME="$TMP/home" SIMULATE_NO_GIT=1 \
    PATH="$TMP/bin:$PATH" bash "$ROOT/get-started.sh" >"$TMP/out" 2>&1; then
    fail 'noninteractive missing Git install continued'
fi
[[ ! -e "$TMP/home/.dotfiles" ]] || fail 'checkout created when Git missing'

printf 'PASS: Stage-zero Git bootstrap syntax, refusal and checkout guards\n'
