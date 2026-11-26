#!/usr/bin/env bash
set -euo pipefail

ROOT=$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)

# shellcheck source=src/lib/common.sh
source "$ROOT/src/lib/common.sh"
# shellcheck source=src/lib/mise.sh
source "$ROOT/src/lib/mise.sh"
# shellcheck source=src/lib/machine-tools.sh
source "$ROOT/src/lib/machine-tools.sh"
# shellcheck source=src/lib/os.sh
source "$ROOT/src/lib/os.sh"

main() {
    # The suite must never consume the caller's terminal input. Tests that need
    # interaction create their own pseudo-terminals and supply input explicitly.
    exec </dev/null

    TEST_ROOT=$(make_temp_dir_physical dotfiles-test)
    trap 'rm -rf -- "$TEST_ROOT"' EXIT

    fail() {
        printf 'FAIL: %s\n' "$*" >&2
        exit 1
    }

    assert_equal() {
        [[ "$1" == "$2" ]] || fail "$3 (expected $1, got $2)"
    }

    # Validate all tracked shell entry points, including newly introduced scripts.
    while IFS= read -r -d '' script; do
        bash -n "$ROOT/$script"
    done < <(git -C "$ROOT" ls-files -z -- '*.sh')
    printf 'PASS: Bash syntax\n'
    [[ ! -e "$ROOT/src/bin/opencode-sandbox" && -x "$ROOT/src/modules/opencode/bin/opencode-sandbox" &&
        -f "$ROOT/src/modules/opencode/Containerfile" ]] ||
        fail 'sandbox launcher must be executable and have a reviewed Containerfile'
    bash -n "$ROOT/src/modules/opencode/bin/opencode-sandbox" || fail 'sandbox launcher has invalid Bash syntax'
    [[ -x "$ROOT/src/bin/,bootstrap" ]] || fail ',bootstrap must be executable'
    bash -n "$ROOT/src/bin/,cleanup" || fail ',cleanup has invalid Bash syntax'
    bash -n "$ROOT/src/bin/,bootstrap" || fail ',bootstrap has invalid Bash syntax'
    # These helpers are also run directly from a shell, not just via Bash in Zellij.
    for helper in ,copy-last ,copy-screen ,copy-pick; do
        [[ -x "$ROOT/src/bin/$helper" ]] || fail "copy helper is not executable: $helper"
        bash -n "$ROOT/src/bin/$helper" || fail "copy helper has invalid Bash syntax: $helper"
    done
    printf 'PASS: Executable Zellij copy helper entry points\n'
    # Portable commands must be executable and valid independently of Zsh.
    for helper in ,vv ,uuid ,wt; do
        [[ -x "$ROOT/src/bin/$helper" ]] || fail "comma command is not executable: $helper"
        bash -n "$ROOT/src/bin/$helper" || fail "invalid Bash syntax: $helper"
    done
    uuid=$("$ROOT/src/bin/,uuid" --lowercase --no-hyphens) || fail ',uuid failed'
    [[ "$uuid" =~ ^[0-9a-f]{32}$ ]] || fail ',uuid did not produce a compact lowercase UUID'
    uuid_help=$("$ROOT/src/bin/,uuid" --help 2>&1) || fail ',uuid help failed'
    [[ "$uuid_help" == *--lowercase* && "$uuid_help" == *--no-hyphens* ]] || fail ",uuid help missing expected flags: $uuid_help"
    [[ -f "$ROOT/src/home/.config/zsh/functions/cdWorktree" ]] || fail 'missing cdWorktree function'
    for helper in ,mason-plugins ,nvim-plugins ,wt; do
        [[ ! -e "$ROOT/src/home/.config/zsh/functions/$helper" ]] || fail "obsolete comma function remains: $helper"
    done
    for helper in cdNvimPlugins cdMasonPlugins; do
        if grep -q "^alias $helper=" "$ROOT/src/home/.config/zsh/aliases.zsh"; then
            fail "obsolete navigation alias remains: $helper"
        fi
    done
    if command -v zsh >/dev/null 2>&1; then
        for helper in "$ROOT"/src/home/.config/zsh/functions/*; do
            zsh -n "$helper" || fail "invalid autoload function: $helper"
        done
    fi
    git init -q "$TEST_ROOT/worktree-source"
    git -C "$TEST_ROOT/worktree-source" -c user.name=Test -c user.email=test@example.invalid \
        commit -q --allow-empty -m initial || fail 'failed to create worktree test fixture'
    worktree_path=$(cd "$TEST_ROOT/worktree-source" && "$ROOT/src/bin/,wt" feature/test) || fail ',wt failed'
    assert_equal "$TEST_ROOT/worktree-source-wt-feature-test" "$worktree_path" ',wt prints destination'
    [[ -d "$worktree_path" ]] || fail ',wt did not create the worktree'
    [[ "$(git -C "$worktree_path" branch --show-current)" == feature/test ]] || fail 'wrong worktree branch'
    if (cd "$TEST_ROOT/worktree-source" && "$ROOT/src/bin/,wt" feature/test) >"$TEST_ROOT/out" 2>"$TEST_ROOT/err"; then
        fail ',wt accepted duplicate branch'
    fi
    [[ ! -s "$TEST_ROOT/out" ]] || fail ',wt printed path on failure'
    if command -v zsh >/dev/null 2>&1; then
        ROOT="$ROOT" TEST_ROOT="$TEST_ROOT" zsh -fc '
      fpath=("$ROOT/src/home/.config/zsh/functions" $fpath)
      export PATH="$ROOT/src/bin:$PATH"
      autoload -Uz cdWorktree
      cd "$TEST_ROOT/worktree-source" || exit
      cdWorktree feature/test || exit
      [[ "$PWD" == "$TEST_ROOT/worktree-source-wt-feature-test" ]] || exit 1
      cd "$TEST_ROOT/worktree-source" || exit
      cdWorktree missing </dev/null && exit 1
      [[ ! -e "$TEST_ROOT/worktree-source-wt-missing" ]] || exit 1
    ' || fail 'cdWorktree navigation or noninteractive refusal failed'
    fi
    printf 'PASS: Portable comma commands and worktree navigation\n'

    printf 'PASS: Executable OpenCode launcher syntax and layout\n'
    if command -v zsh >/dev/null 2>&1; then
        zsh -n "$ROOT/src/home/.zshrc" || fail 'reviewed zsh file has invalid syntax'
        zsh -n "$ROOT/src/home/.config/zsh/aliases.zsh" || fail 'reviewed zsh aliases have invalid syntax'
        zsh -n "$ROOT/src/home/.config/zsh/zoxide-bookmarks.zsh" || fail 'zoxide bookmarks have invalid syntax'
        zsh -n "$ROOT/src/home/.config/zsh/completions.zsh" || fail 'zoxide completions have invalid syntax'
        mkdir -p "$TEST_ROOT/data/nvim/lazy" "$TEST_ROOT/data/nvim/mason/packages"
        ROOT="$ROOT" TEST_ROOT="$TEST_ROOT" zsh -fc '
      export XDG_DATA_HOME="$TEST_ROOT/data"
      __zoxide_z() { [[ "$1" == fallback ]] || return 1; }
      source "$ROOT/src/home/.config/zsh/zoxide-bookmarks.zsh" || exit
      z nvim-plugins || { print -u2 "nvim-plugins bookmark failed"; exit 1; }
      [[ "$(pwd -P)" == "$(cd "$TEST_ROOT/data/nvim/lazy" && pwd -P)" ]] ||
        { print -u2 "nvim-plugins path mismatch: $PWD"; exit 1; }
      z mason-plugins || { print -u2 "mason-plugins bookmark failed"; exit 1; }
      [[ "$(pwd -P)" == "$(cd "$TEST_ROOT/data/nvim/mason/packages" && pwd -P)" ]] ||
        { print -u2 "mason-plugins path mismatch: $PWD"; exit 1; }
      z fallback || { print -u2 "zoxide fallback failed"; exit 1; }
      if z unknown-bookmark >/dev/null 2>&1; then
        print -u2 "unknown bookmark unexpectedly succeeded"
        exit 1
      fi
    ' || fail 'zoxide bookmarks navigation or fallback failed'
        zsh -n "$ROOT/src/home/.config/zsh/p10k.zsh" || fail 'reviewed p10k config has invalid syntax'
        zsh -n "$ROOT/src/home/.config/zsh/autosuggestions.zsh" || fail 'autosuggestion config has invalid syntax'
        zsh "$ROOT/dev/tests/zoxide-autosuggestions.zsh" || fail 'bookmark autosuggestions tests failed'
        printf 'PASS: Reviewed zsh syntax\n'
    else
        printf 'SKIP: Reviewed zsh syntax (zsh not found)\n'
    fi

    [[ ! -e "$ROOT/src/lib/setup/bootstrap.sh" ]] || fail "obsolete bootstrap script should not remain"
    [[ ! -e "$ROOT/src/lib/setup/apply-private-overlay.sh" &&
        ! -e "$ROOT/dev/tests/tool-overlay-interactive.py" ]] ||
        fail 'obsolete directory-link POC must not remain'
    for moved in cleanup update; do
        [[ ! -e "$ROOT/scripts/$moved.sh" ]] || fail "obsolete setup path remains: $moved"
        [[ -x "$ROOT/src/lib/setup/$moved.sh" ]] || fail "setup script is not executable: $moved"
    done
    for moved in format lint install-hooks install-dev-tools install-docs-deps build-docs check-clean; do
        [[ ! -e "$ROOT/scripts/$moved.sh" ]] || fail "obsolete dev path remains: $moved"
        [[ -x "$ROOT/dev/scripts/$moved.sh" ]] || fail "development script is not executable: $moved"
    done
    [[ ! -e "$ROOT/scripts/update.sh" && ! -e "$ROOT/src/lib/setup/provision-tool.sh" &&
        ! -e "$ROOT/src/lib/setup/deploy-zsh-config.sh" && ! -e "$ROOT/src/lib/setup/deploy-zellij-config.sh" ]] ||
        fail 'obsolete setup placeholders should not remain'
    [[ ! -d "$ROOT/scripts" ]] || fail "obsolete scripts/ directory remains"
    [[ ! -e "$ROOT/get-started.sh" ]] || fail "obsolete stage-zero installer should not remain"
    [[ -f "$ROOT/dev/mise.toml" && -f "$ROOT/lefthook.yml" && ! -e "$ROOT/mise.toml" ]] ||
        fail 'expected checkout tool configuration missing'
    printf 'PASS: Checkout script layout and executable modes\n'
    # Validate the real machine manifest with mise without installing anything.
    # This must not accidentally include the root checkout's developer tools.
    # Resolve mise as setup does: it may be installed outside the current PATH.
    if mise=$(mise_command); then
        machine_config="$ROOT/src/mise.toml"
        MISE_GLOBAL_CONFIG_FILE="$machine_config" "$mise" -C / config ls >/dev/null ||
            fail 'mise could not parse the machine-only manifest'
        tool_listing=$(MISE_GLOBAL_CONFIG_FILE="$machine_config" "$mise" -C / ls --current) ||
            fail 'mise could not resolve machine tool declarations'
        [[ -n "$tool_listing" ]] ||
            fail 'machine manifest should expose at least one declared tool'
        [[ "$tool_listing" != *shellcheck* && "$tool_listing" != *lefthook* ]] ||
            fail 'developer tools leaked into machine setup'
        # Exercise the real mise CLI (rather than just synthetic fixtures) to
        # ensure the shared enumerator handles requested-but-missing versions.
        machine_specs=$(MISE_GLOBAL_CONFIG_FILE="$machine_config" \
            machine_tool_specs "$mise" "$ROOT/src/home/.config/mise/base-tools.toml") ||
            fail 'machine tool enumerator could not read the reviewed mise config'
        [[ -n "$machine_specs" ]] || fail 'machine tool inventory is unexpectedly empty'
        [[ "$machine_specs" != *lefthook* && "$machine_specs" != *shellcheck* ]] ||
            fail 'developer tools leaked into the machine tool inventory'
        printf 'PASS: Native mise machine manifest loads without developer tools\n'
    fi

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
    # Run twice from elsewhere, with an isolated HOME, on a supported host only.
    if detect_os >/dev/null 2>&1; then
        output=$(cd "$TEST_ROOT/elsewhere" && env HOME="$TEST_ROOT/home" \
            PATH="$TEST_ROOT/bin:$PATH" bash "$ROOT/src/bin/,bootstrap" --no-update)
        repeated=$(cd "$TEST_ROOT/elsewhere" && env HOME="$TEST_ROOT/home" \
            PATH="$TEST_ROOT/bin:$PATH" bash "$ROOT/src/bin/,bootstrap" --no-update)
        assert_equal "$output" "$repeated" 'bootstrap repeatability'
        [[ "$output" == *'✓ Bootstrap complete. Dotfiles:'* &&
            "$output" != *'[info]'* ]] || fail 'bootstrap scope unclear'
    else
        printf 'SKIP: bootstrap host smoke test (unsupported host)\n'
    fi
    [[ -z "$(find "$TEST_ROOT/home" "$TEST_ROOT/elsewhere" -mindepth 1 -type f ! -path "$TEST_ROOT/home/.local/state/dotfiles/logs/*" -print)" ]] ||
        fail 'entry point wrote outside its isolated bootstrap log directory'
    printf 'PASS: Entry-point help, errors and repeatable smoke execution\n'
    bash "$ROOT/dev/tests/check-clean.sh"
    if command -v python3 >/dev/null 2>&1; then
        python3 "$ROOT/dev/tests/docs-generation.py"
        python3 "$ROOT/dev/tests/update-interactive.py"
        python3 "$ROOT/dev/tests/bootstrap-command.py"
        python3 "$ROOT/dev/tests/bootstrap-interactive.py"
        python3 "$ROOT/dev/tests/zsh-startup.py"
        python3 "$ROOT/dev/tests/mise-native-modules.py"
        python3 "$ROOT/dev/tests/mise-bootstrap-interactive.py"
        python3 "$ROOT/dev/tests/login-shell.py"
        python3 "$ROOT/dev/tests/cleanup-interactive.py"
        python3 "$ROOT/dev/tests/cleanup-reset.py"
        python3 "$ROOT/dev/tests/opencode-sandbox.py"
        python3 "$ROOT/dev/tests/podman-setup.py"
        python3 "$ROOT/dev/tests/prompt-setup.py"
        python3 "$ROOT/dev/tests/font-setup.py"
        python3 "$ROOT/dev/tests/autosuggestions-setup.py"
        python3 "$ROOT/dev/tests/dev-setup-interactive.py"
    else
        printf 'SKIP: interactive bootstrap tests (python3 not found)\n'
    fi
    printf 'All bootstrap checks passed.\n'
}

main "$@"
