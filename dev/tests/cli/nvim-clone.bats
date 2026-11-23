#!/usr/bin/env bats

setup() {
  COMMON="$BATS_TEST_DIRNAME/../../../lib/common.sh"
  NVIM="$BATS_TEST_DIRNAME/../../../lib/nvim.sh"
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  export NVIM_GH_TEST_LOG="$BATS_TEST_TMPDIR/gh.log"
  export NVIM_GH_TEST_STATUS=0
  config="$BATS_TEST_TMPDIR/config with spaces"
  cat > "$BATS_TEST_TMPDIR/bin/gh" <<'GH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$NVIM_GH_TEST_LOG"
case "$1 $2" in
  "auth status") exit "$NVIM_GH_TEST_STATUS" ;;
  "repo clone")
    [[ "$3" == https://github.com/daniel-price/lazyvim.git ]] || exit 41
    [[ "$4" == "$NVIM_GH_TEST_CONFIG" ]] || exit 42
    [[ "$5" == -- && "$6" == --branch && "$7" == main && "$8" == --single-branch ]] || exit 43
    [[ "$GIT_CONFIG_COUNT" == 2 ]] || exit 44
    [[ "$GIT_CONFIG_KEY_0" == credential.helper && -z "$GIT_CONFIG_VALUE_0" ]] || exit 45
    [[ "$GIT_CONFIG_KEY_1" == credential.https://github.com.helper ]] || exit 46
    [[ "$GIT_CONFIG_VALUE_1" == '!gh auth git-credential' ]] || exit 47
    mkdir -p "$4"
    ;;
  *) exit 48 ;;
esac
GH
  chmod +x "$BATS_TEST_TMPDIR/bin/gh"
  export NVIM_GH_TEST_CONFIG="$config"
}

clone_checkout() {
  bash -c 'source "$1"; source "$2"; nvim_clone_checkout "$3"' _ "$COMMON" "$NVIM" "$config"
}

@test "Neovim checkout uses authenticated gh clone over HTTPS without persistent credential changes" {
  run clone_checkout
  [ "$status" -eq 0 ]
  [ -d "$config" ]
  [[ "$output" != *"token"* ]]
  grep -q '^auth status --hostname github.com$' "$NVIM_GH_TEST_LOG"
  grep -q '^repo clone https://github.com/daniel-price/lazyvim.git ' "$NVIM_GH_TEST_LOG"
}

@test "Neovim clone refuses unauthenticated gh without creating config" {
  export NVIM_GH_TEST_STATUS=1
  run clone_checkout
  [ "$status" -ne 0 ]
  [[ "$output" == *'gh auth login'* ]]
  [ ! -e "$config" ]
  [ "$(wc -l < "$NVIM_GH_TEST_LOG")" -eq 1 ]
}

@test "Neovim clone refuses missing gh rather than using plain git" {
  run bash -c '
    source "$1"
    source "$2"
    command -v gh
  ' _ "$COMMON" "$NVIM"
  [ "$status" -eq 0 ]
  rm -f "$BATS_TEST_TMPDIR/bin/gh"
  # A clean PATH fixture avoids CI runners' system gh installations.
  mkdir -p "$BATS_TEST_TMPDIR/only-tools"
  ln -s "$(command -v bash)" "$BATS_TEST_TMPDIR/only-tools/bash"
  run env PATH="$BATS_TEST_TMPDIR/only-tools" bash -c 'source "$1"; source "$2"; nvim_clone_checkout "$3"' _ "$COMMON" "$NVIM" "$config"
  [ "$status" -ne 0 ]
  [[ "$output" == *'GitHub CLI is unavailable'* ]]
  [ ! -e "$config" ]
}
