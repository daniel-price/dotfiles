#!/usr/bin/env bash
set -euo pipefail

ROOT=$(CDPATH='' cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-test.XXXXXX")
trap 'rm -rf -- "$TEST_ROOT"' EXIT

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

assert_equal() {
    [[ "$1" == "$2" ]] || fail "$3 (expected $1, got $2)"
}

for script in "$ROOT/get-started.sh" "$ROOT/scripts/bootstrap.sh" \
    "$ROOT/scripts/apply-private-overlay.sh" "$ROOT/scripts/check-clean.sh" \
    "$ROOT/scripts/deploy-zsh-config.sh" "$ROOT/scripts/format.sh" \
    "$ROOT/scripts/install-dev-tools.sh" "$ROOT/scripts/install-ghostty.sh" \
    "$ROOT/scripts/install-hooks.sh" "$ROOT/scripts/lint.sh" \
    "$ROOT/scripts/provision-tool.sh" "$ROOT/scripts/update.sh" \
    "$ROOT/scripts/lib/common.sh" "$ROOT/scripts/lib/mise.sh" \
    "$ROOT/scripts/lib/os.sh" "$ROOT/scripts/lib/shell-files.sh" \
    "$ROOT/tests/check-clean.sh" "$ROOT/tests/get-started.sh" "$ROOT/tests/run.sh"; do
    bash -n "$script"
done
printf 'PASS: Bash syntax\n'
if command -v zsh >/dev/null 2>&1; then
    zsh -n "$ROOT/.config/zsh/zshrc" || fail 'reviewed zsh file has invalid syntax'
    printf 'PASS: Reviewed zsh syntax\n'
else
    printf 'SKIP: Reviewed zsh syntax (zsh not found)\n'
fi

for moved in bootstrap update; do
    [[ ! -e "$ROOT/$moved.sh" ]] || fail "legacy root $moved script remains"
    [[ -x "$ROOT/scripts/$moved.sh" ]] || fail "moved $moved script is not executable"
done
[[ -f "$ROOT/get-started.sh" && -f "$ROOT/mise.toml" && -f "$ROOT/lefthook.yml" ]] ||
    fail 'expected root entry points or tool configuration missing'
printf 'PASS: Checkout script layout and executable modes\n'

source "$ROOT/scripts/lib/os.sh"
source "$ROOT/scripts/lib/common.sh"

assert_equal macos "$(detect_os Darwin "$TEST_ROOT/missing")" 'macOS without Linux metadata'

check_linux() {
    local label=$1
    local metadata=$2
    printf '%s\n' "$metadata" >"$TEST_ROOT/os-release"
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
printf 'ID=custom\nID_LIKE="ubuntu debian"' >"$TEST_ROOT/os-release"
assert_equal debian "$(detect_os Linux "$TEST_ROOT/os-release")" 'no trailing newline'

for metadata in 'ID=fedora' 'ID=notdebian' 'NAME="Unknown"' ''; do
    printf '%s\n' "$metadata" >"$TEST_ROOT/os-release"
    if detect_os Linux "$TEST_ROOT/os-release" >"$TEST_ROOT/out" 2>"$TEST_ROOT/err"; then
        fail 'unsupported/unknown Linux accepted'
    fi
    [[ -s "$TEST_ROOT/err" && ! -s "$TEST_ROOT/out" ]] || fail 'missing detection error'
done
if detect_os Linux "$TEST_ROOT/missing" >"$TEST_ROOT/out" 2>"$TEST_ROOT/err"; then
    fail 'missing metadata accepted'
fi
if detect_os FreeBSD >"$TEST_ROOT/out" 2>"$TEST_ROOT/err"; then
    fail 'unsupported kernel accepted'
fi

# Metadata must remain data, even when it contains shell syntax.
# Literal shell syntax must remain inert metadata.
# shellcheck disable=SC2016
printf '%s\n' 'ID=debian' 'touch "$TEST_ROOT/metadata-executed"' >"$TEST_ROOT/os-release"
assert_equal debian "$(detect_os Linux "$TEST_ROOT/os-release")" 'metadata treated as data'
[[ ! -e "$TEST_ROOT/metadata-executed" ]] || fail 'os-release executed as shell'
printf 'PASS: OS detection fixtures and failure cases\n'

if confirm 'Test action' </dev/null >"$TEST_ROOT/out" 2>"$TEST_ROOT/err"; then
    fail 'noninteractive confirmation accepted'
fi
if printf 'yes\n' | confirm 'Test action' >"$TEST_ROOT/out" 2>"$TEST_ROOT/err"; then
    fail 'piped confirmation accepted'
fi
if confirm '' </dev/null >"$TEST_ROOT/out" 2>"$TEST_ROOT/err"; then
    fail 'empty action description accepted'
fi
printf 'PASS: Confirmation refuses noninteractive approval\n'

mkdir "$TEST_ROOT/bin" "$TEST_ROOT/home" "$TEST_ROOT/elsewhere"
cat >"$TEST_ROOT/bin/mise" <<'MISE'
#!/usr/bin/env bash
case "$1" in
--version)
    printf '%s\n' '2026.11.9 fake'
    ;;
-C)
    shift 2
    case "$1" in
    install) exit 0 ;;
    *) exit 0 ;;
    esac
    ;;
*) exit 0 ;;
esac
MISE
chmod +x "$TEST_ROOT/bin/mise"
cat >"$TEST_ROOT/bin/apt-cache" <<'APT_CACHE'
#!/usr/bin/env bash
printf '%s\n' '  Candidate: 1.4.0'
APT_CACHE
cat >"$TEST_ROOT/bin/dpkg-query" <<'DPKG_QUERY'
#!/usr/bin/env bash
printf '%s\n' 'deinstall ok config-files'
DPKG_QUERY
printf '%s\n' '#!/usr/bin/env bash' 'exec "$@"' >"$TEST_ROOT/bin/sudo"
printf '%s\n' '#!/usr/bin/env bash' 'exit 0' >"$TEST_ROOT/bin/add-apt-repository"
cat >"$TEST_ROOT/bin/brew" <<'BREW'
#!/usr/bin/env bash
case "$1" in
list) exit 1 ;;
*) exit 0 ;;
esac
BREW
chmod +x "$TEST_ROOT/bin/apt-cache" "$TEST_ROOT/bin/dpkg-query" \
    "$TEST_ROOT/bin/sudo" "$TEST_ROOT/bin/add-apt-repository" \
    "$TEST_ROOT/bin/brew"
for entry in bootstrap update; do
    for help in -h --help; do
        output=$(bash "$ROOT/scripts/$entry.sh" "$help")
        [[ "$output" == *'Usage:'* ]] || fail "$entry help missing"
    done
    if bash "$ROOT/scripts/$entry.sh" --unknown >"$TEST_ROOT/out" 2>"$TEST_ROOT/err"; then
        fail "$entry accepted unknown argument"
    fi
    if bash "$ROOT/scripts/$entry.sh" --help extra >"$TEST_ROOT/out" 2>"$TEST_ROOT/err"; then
        fail "$entry accepted extra argument"
    fi
    # Run twice from elsewhere, with an isolated HOME, on a supported host only.
    if detect_os >/dev/null 2>&1; then
        output=$(cd "$TEST_ROOT/elsewhere" && HOME="$TEST_ROOT/home" \
            PATH="$TEST_ROOT/bin:$PATH" bash "$ROOT/scripts/$entry.sh")
        repeated=$(cd "$TEST_ROOT/elsewhere" && HOME="$TEST_ROOT/home" \
            PATH="$TEST_ROOT/bin:$PATH" bash "$ROOT/scripts/$entry.sh")
        assert_equal "$output" "$repeated" "$entry repeatability"
        if [[ "$entry" == bootstrap ]]; then
            [[ "$output" == *'Detected platform:'* && "$output" == *'Bootstrap complete.'* &&
                "$output" == *'Not implemented:'* ]] || fail 'bootstrap scope unclear'
        else
            [[ "$output" == *'scaffolding only'* && "$output" == *'Not implemented:'* &&
                "$output" == *'No changes made.'* ]] || fail 'update scope unclear'
        fi
    else
        printf 'SKIP: %s host smoke test (unsupported host)\n' "$entry"
    fi
done
[[ -z "$(find "$TEST_ROOT/home" "$TEST_ROOT/elsewhere" -mindepth 1 -print)" ]] ||
    fail 'entry point wrote to isolated home or working directory'
printf 'PASS: Entry-point help, errors and repeatable smoke execution\n'
bash "$ROOT/tests/check-clean.sh"
bash "$ROOT/tests/get-started.sh"
if command -v python3 >/dev/null 2>&1; then
    python3 "$ROOT/tests/get-started-interactive.py"
    python3 "$ROOT/tests/bootstrap-interactive.py"
    python3 "$ROOT/tests/tool-overlay-interactive.py"
    python3 "$ROOT/tests/zsh-deploy-interactive.py"
    python3 "$ROOT/tests/provision-zellij-interactive.py"
    python3 "$ROOT/tests/install-ghostty-interactive.py"
else
    printf 'SKIP: interactive bootstrap tests (python3 not found)\n'
fi
printf 'All bootstrap checks passed.\n'
