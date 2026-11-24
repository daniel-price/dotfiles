#!/usr/bin/env bash
set -euo pipefail

ROOT=$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)

main() {
    TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-hooks.XXXXXX")
    trap 'rm -rf -- "$TEST_ROOT"' EXIT
    fail() {
        printf 'FAIL: %s\n' "$*" >&2
        exit 1
    }

    # All Git writes and temporary trust apply only to this synthetic repository.
    export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
    mkdir "$TEST_ROOT/repo"
    cd "$TEST_ROOT/repo"
    export MISE_TRUSTED_CONFIG_PATHS="$TEST_ROOT/repo"
    mkdir -p dev/scripts dev/lib lib
    cp "$ROOT/dev/mise.toml" dev/mise.toml
    cp "$ROOT/lefthook.yml" .
    cp "$ROOT/dev/scripts/install-hooks.sh" "$ROOT/dev/scripts/run-mise.sh" dev/scripts/
    cp "$ROOT/dev/scripts/format.sh" "$ROOT/dev/scripts/lint.sh" dev/scripts/
    cp "$ROOT/src/lib/common.sh" "$ROOT/src/lib/mise.sh" src/lib/
    cp "$ROOT/dev/lib/shell-files.sh" dev/lib/
    git init -q
    git config user.name 'Hook test'
    git config user.email 'hook-test@example.invalid'
    git config commit.gpgsign false

    # Piping yes must not enable hooks, and an unrelated hook must be preserved.
    printf 'yes\n' | bash dev/scripts/install-hooks.sh >"$TEST_ROOT/setup.log" 2>&1
    [[ ! -e .git/hooks/pre-commit ]] || fail 'noninteractive setup installed hooks'
    grep -q 'installation declined' "$TEST_ROOT/setup.log" || fail 'decline was not reported'
    printf '#!/bin/sh\nexit 0\n' >.git/hooks/pre-commit
    cp .git/hooks/pre-commit "$TEST_ROOT/original-hook"
    if bash dev/scripts/install-hooks.sh >"$TEST_ROOT/setup.log" 2>&1; then
        fail 'unrelated hook accepted'
    fi
    cmp .git/hooks/pre-commit "$TEST_ROOT/original-hook" || fail 'unrelated hook changed'
    rm .git/hooks/pre-commit
    git config core.hooksPath "$TEST_ROOT/custom-hooks"
    if bash dev/scripts/install-hooks.sh >"$TEST_ROOT/setup.log" 2>&1; then
        fail 'configured hooksPath accepted'
    fi
    [[ ! -e "$TEST_ROOT/custom-hooks" ]] || fail 'configured hooksPath was written'
    git config --unset core.hooksPath
    printf 'PASS: Setup declines piped approval and preserves hook conflicts\n'

    cat >'partial file.sh' <<'SHELL'
#!/usr/bin/env bash
greet() {
    printf '%s\n' original
}
greet
SHELL
    git add .
    git commit -qm 'Seed fixture before hook installation'

    # Command help and unknown flags must not modify the fixture.
    bash dev/scripts/format.sh --help >"$TEST_ROOT/format-help.log"
    bash dev/scripts/lint.sh --help >"$TEST_ROOT/lint-help.log"
    grep -q 'Usage:' "$TEST_ROOT/format-help.log" || fail 'format help missing'
    grep -q 'Usage:' "$TEST_ROOT/lint-help.log" || fail 'lint help missing'
    if bash dev/scripts/format.sh --unknown >"$TEST_ROOT/format-error.log" 2>&1; then
        fail 'format accepted an unknown option'
    elif [[ $? -ne 2 ]]; then
        fail 'format unknown option returned the wrong status'
    fi
    if bash dev/scripts/lint.sh --unknown >"$TEST_ROOT/lint-error.log" 2>&1; then
        fail 'lint accepted an unknown option'
    elif [[ $? -ne 2 ]]; then
        fail 'lint unknown option returned the wrong status'
    fi

    # Selected paths, including spaces, use repository-relative names.
    bash dev/scripts/format.sh --check -- 'partial file.sh'
    bash dev/scripts/lint.sh -- 'partial file.sh'

    # A selected script can source a tracked helper that is not in the file list.
    (
        cd "$TEST_ROOT"
        bash "$TEST_ROOT/repo/dev/scripts/format.sh" --check -- dev/scripts/format.sh
        bash "$TEST_ROOT/repo/dev/scripts/lint.sh" -- dev/scripts/lint.sh
    ) || fail 'selected lint from another directory failed'

    # An empty tracked shell-file selection must succeed without invoking tools.
    empty="$TEST_ROOT/empty"
    mkdir -p "$empty/dev/scripts" "$empty/dev/lib"
    cp dev/scripts/format.sh dev/scripts/lint.sh "$empty/dev/scripts/"
    cp dev/lib/shell-files.sh "$empty/dev/lib/"
    git -C "$empty" init -q
    printf 'No shell scripts are tracked.\n' >"$empty/notes.md"
    git -C "$empty" add notes.md
    format_empty=$(cd "$empty" && bash dev/scripts/format.sh --check)
    lint_empty=$(cd "$empty" && bash dev/scripts/lint.sh)
    [[ "$format_empty" == 'No tracked shell scripts to format.' ]] ||
        fail 'format empty selection was not reported'
    [[ "$lint_empty" == 'No tracked shell scripts to lint.' ]] ||
        fail 'lint empty selection was not reported'
    git diff --quiet || fail 'format or lint command changed the fixture'
    git diff --cached --quiet || fail 'format or lint command changed the fixture'
    printf 'PASS: Format and lint command options, selected files and empty selection\n'

    bash dev/scripts/run-mise.sh exec -- lefthook install pre-commit >"$TEST_ROOT/install.log" 2>&1
    bash dev/scripts/install-hooks.sh >"$TEST_ROOT/setup.log" 2>&1
    grep -q 'already installed' "$TEST_ROOT/setup.log" || fail 'repeat setup did not skip'

    cat >'partial file.sh' <<'SHELL'
#!/usr/bin/env bash
greet(){
printf '%s\n' staged
}
greet
SHELL
    git add 'partial file.sh'
    git show ':partial file.sh' >"$TEST_ROOT/expected.sh"
    bash dev/scripts/run-mise.sh exec -- shfmt -w -i 4 "$TEST_ROOT/expected.sh"
    printf '# Unstaged work in progress\n' >>'partial file.sh'
    git commit -qm 'Format only staged content' >"$TEST_ROOT/commit.log" 2>&1 || {
        cat "$TEST_ROOT/commit.log"
        fail 'partially staged commit failed'
    }
    git show 'HEAD:partial file.sh' >"$TEST_ROOT/committed.sh"
    cmp "$TEST_ROOT/expected.sh" "$TEST_ROOT/committed.sh" || fail 'commit differs from formatted staged content'
    cat "$TEST_ROOT/expected.sh" >"$TEST_ROOT/working.sh"
    printf '# Unstaged work in progress\n' >>"$TEST_ROOT/working.sh"
    cmp "$TEST_ROOT/working.sh" 'partial file.sh' || fail 'unstaged edits were not restored'
    git diff --cached --quiet || fail 'unexpected staged changes after commit'
    printf 'PASS: Real commit formats selected content and preserves unstaged edits\n'

    cat >bad.sh <<'SHELL'
#!/usr/bin/env bash
value='two words'
printf '%s\n' $value
SHELL
    git add bad.sh
    before=$(git rev-parse HEAD)
    if git commit -qm 'Must be rejected' >"$TEST_ROOT/lint.log" 2>&1; then
        fail 'ShellCheck error did not block the commit'
    fi
    [[ "$(git rev-parse HEAD)" == "$before" ]] || fail 'failed lint created a commit'
    grep -q SC2086 "$TEST_ROOT/lint.log" || fail 'ShellCheck diagnostic missing'
    printf 'PASS: ShellCheck blocks an invalid commit\n'

    # The check command must report errors without changing either Git snapshot.
    printf '#!/usr/bin/env bash\nprintf    "format me\\n"\n' >'partial file.sh'
    git diff --binary >"$TEST_ROOT/work.before"
    git diff --cached --binary >"$TEST_ROOT/index.before"
    if bash dev/scripts/run-mise.sh run check >"$TEST_ROOT/check.log" 2>&1; then
        fail 'read-only check accepted invalid scripts'
    fi
    git diff --binary >"$TEST_ROOT/work.after"
    git diff --cached --binary >"$TEST_ROOT/index.after"
    cmp "$TEST_ROOT/work.before" "$TEST_ROOT/work.after" || fail 'check changed working files'
    cmp "$TEST_ROOT/index.before" "$TEST_ROOT/index.after" || fail 'check changed staging'
    bash dev/scripts/run-mise.sh run format >"$TEST_ROOT/format.log" 2>&1
    git diff --cached --binary >"$TEST_ROOT/index.after"
    cmp "$TEST_ROOT/index.before" "$TEST_ROOT/index.after" || fail 'format staged changes'
    if bash dev/scripts/run-mise.sh run check >"$TEST_ROOT/lint-check.log" 2>&1; then
        fail 'read-only check accepted ShellCheck errors'
    fi
    grep -q SC2086 "$TEST_ROOT/lint-check.log" || fail 'read-only check omitted ShellCheck error'
    printf 'PASS: Check is read-only; explicit formatting leaves staging alone\n'

    git rm --cached -q bad.sh
    rm bad.sh
    printf 'Documentation only\n' >notes.md
    git add notes.md
    git commit -qm 'Commit without staged shell changes' >"$TEST_ROOT/non-shell.log" 2>&1 ||
        fail 'non-shell commit failed'
    printf 'PASS: Non-shell commits skip shell jobs\n'
}

main "$@"
