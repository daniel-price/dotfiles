#!/usr/bin/env bash
set -euo pipefail

ROOT=$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)


# shellcheck source=scripts/lib/common.sh
source "$ROOT/scripts/lib/common.sh"

main() {
    TEST_ROOT=$(make_temp_dir_physical dotfiles-clean)
    trap 'rm -rf -- "$TEST_ROOT"' EXIT

    fail() {
        printf 'FAIL: %s\n' "$*" >&2
        exit 1
    }

    repo="$TEST_ROOT/repo"
    mkdir -p "$repo/scripts/dev" "$TEST_ROOT/elsewhere"
    cp "$ROOT/scripts/dev/check-clean.sh" "$repo/scripts/dev/"
    git -C "$repo" init -q
    git -C "$repo" config user.name 'Clean check test'
    git -C "$repo" config user.email 'clean-check@example.invalid'
    printf 'initial\n' >"$repo/README.md"
    git -C "$repo" add README.md
    git -C "$repo" commit -qm 'Seed clean fixture'

    (cd "$TEST_ROOT/elsewhere" && bash "$repo/scripts/dev/check-clean.sh") ||
        fail 'clean checkout rejected from another directory'

    printf 'working change\n' >"$repo/README.md"
    if bash "$repo/scripts/dev/check-clean.sh" >"$TEST_ROOT/working.log" 2>&1; then
        fail 'unstaged change accepted'
    fi
    grep -q 'working change' "$TEST_ROOT/working.log" ||
        fail 'unstaged change missing from report'

    printf 'initial\n' >"$repo/README.md"
    git -C "$repo" add README.md
    printf 'staged change\n' >"$repo/README.md"
    git -C "$repo" add README.md
    if bash "$repo/scripts/dev/check-clean.sh" >"$TEST_ROOT/staged.log" 2>&1; then
        fail 'staged change accepted'
    fi
    grep -q 'staged change' "$TEST_ROOT/staged.log" ||
        fail 'staged change missing from report'

    printf 'PASS: Clean-check success, unstaged and staged failure cases\n'
}

main "$@"
