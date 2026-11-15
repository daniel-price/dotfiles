#!/usr/bin/env bash
set -euo pipefail

ROOT=$(CDPATH= cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-test.XXXXXX")
trap 'rm -rf -- "$TEST_ROOT"' EXIT

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

assert_equal() {
    [[ "$1" == "$2" ]] || fail "$3 (expected $1, got $2)"
}

for script in "$ROOT/bootstrap.sh" "$ROOT/update.sh" \
    "$ROOT/scripts/lib/common.sh" "$ROOT/scripts/lib/os.sh" "$ROOT/tests/run.sh"; do
    bash -n "$script"
done
printf 'PASS: Bash syntax\n'

source "$ROOT/scripts/lib/os.sh"
source "$ROOT/scripts/lib/common.sh"

assert_equal macos "$(detect_os Darwin "$TEST_ROOT/missing")" 'macOS without Linux metadata'

check_linux() {
    local label=$1
    local metadata=$2
    printf '%s\n' "$metadata" > "$TEST_ROOT/os-release"
    assert_equal debian "$(detect_os Linux "$TEST_ROOT/os-release")" "$label"
}

check_linux Debian 'ID=debian'
check_linux Ubuntu 'ID=ubuntu'
check_linux Pop_OS 'ID=pop'
check_linux Pop_OS_ancestry 'ID=pop
ID_LIKE="ubuntu debian"'
check_linux derivative 'ID=linuxmint
ID_LIKE="ubuntu debian"'
check_linux single_quotes "ID='custom'
ID_LIKE='debian'"
# Exact tokens, not substrings; also cover a final line without a newline.
printf 'ID=custom\nID_LIKE="ubuntu debian"' > "$TEST_ROOT/os-release"
assert_equal debian "$(detect_os Linux "$TEST_ROOT/os-release")" 'no trailing newline'

for metadata in 'ID=fedora' 'ID=notdebian' 'NAME="Unknown"' ''; do
    printf '%s\n' "$metadata" > "$TEST_ROOT/os-release"
    if detect_os Linux "$TEST_ROOT/os-release" > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"; then
        fail 'unsupported/unknown Linux accepted'
    fi
    [[ -s "$TEST_ROOT/err" && ! -s "$TEST_ROOT/out" ]] || fail 'missing detection error'
done
if detect_os Linux "$TEST_ROOT/missing" > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"; then
    fail 'missing metadata accepted'
fi
if detect_os FreeBSD > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"; then
    fail 'unsupported kernel accepted'
fi

# Metadata must remain data, even when it contains shell syntax.
printf '%s\n' 'ID=debian' 'touch "$TEST_ROOT/metadata-executed"' > "$TEST_ROOT/os-release"
assert_equal debian "$(detect_os Linux "$TEST_ROOT/os-release")" 'metadata treated as data'
[[ ! -e "$TEST_ROOT/metadata-executed" ]] || fail 'os-release executed as shell'
printf 'PASS: OS detection fixtures and failure cases\n'

if confirm 'Test action' < /dev/null > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"; then
    fail 'noninteractive confirmation accepted'
fi
if printf 'yes\n' | confirm 'Test action' > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"; then
    fail 'piped confirmation accepted'
fi
if confirm '' < /dev/null > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"; then
    fail 'empty action description accepted'
fi
printf 'PASS: Confirmation refuses noninteractive approval\n'

mkdir "$TEST_ROOT/home" "$TEST_ROOT/elsewhere"
for entry in bootstrap update; do
    for help in -h --help; do
        output=$(bash "$ROOT/$entry.sh" "$help")
        [[ "$output" == *'Usage:'* ]] || fail "$entry help missing"
    done
    if bash "$ROOT/$entry.sh" --unknown > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"; then
        fail "$entry accepted unknown argument"
    fi
    if bash "$ROOT/$entry.sh" --help extra > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"; then
        fail "$entry accepted extra argument"
    fi
    # Run twice from elsewhere, with an isolated HOME, on a supported host only.
    if detect_os > /dev/null 2>&1; then
        output=$(cd "$TEST_ROOT/elsewhere" && HOME="$TEST_ROOT/home" bash "$ROOT/$entry.sh")
        repeated=$(cd "$TEST_ROOT/elsewhere" && HOME="$TEST_ROOT/home" bash "$ROOT/$entry.sh")
        assert_equal "$output" "$repeated" "$entry repeatability"
        [[ "$output" == *'scaffolding only'* && "$output" == *'Not implemented:'* \
            && "$output" == *'No changes made.'* ]] || fail "$entry scope unclear"
    else
        printf 'SKIP: %s host smoke test (unsupported host)\n' "$entry"
    fi
done
[[ -z "$(find "$TEST_ROOT/home" "$TEST_ROOT/elsewhere" -mindepth 1 -print)" ]] \
    || fail 'entry point wrote to isolated home or working directory'
printf 'PASS: Entry-point help, errors and repeatable smoke execution\n'
printf 'All scaffold checks passed.\n'
