#!/usr/bin/env bats

setup() {
  COMMON="$BATS_TEST_DIRNAME/../../../src/lib/common.sh"
  NVIM="$BATS_TEST_DIRNAME/../../../src/lib/nvim.sh"
  source_repo="$BATS_TEST_TMPDIR/source"
  remote="$BATS_TEST_TMPDIR/remote.git"
  config="$BATS_TEST_TMPDIR/config"

  git init -q -b main "$source_repo"
  git -C "$source_repo" config user.name Test
  git -C "$source_repo" config user.email test@example.invalid
  echo '{}' > "$source_repo/lazy-lock.json"
  git -C "$source_repo" add lazy-lock.json
  git -C "$source_repo" -c commit.gpgsign=false commit -q -m initial

  git init -q --bare "$remote"
  git -C "$source_repo" remote add origin "$remote"
  git -C "$source_repo" push -q origin main
  git clone -q -b main "$remote" "$config"
  git -C "$config" config user.name Test
  git -C "$config" config user.email test@example.invalid
}

sync_checkout() {
  bash -c 'source "$1"; source "$2"; nvim_sync_checkout "$3" "$4"' \
    _ "$COMMON" "$NVIM" "$config" "${1:-}"
}

upstream_commit() {
  echo "$1" > "$source_repo/lazy-lock.json"
  git -C "$source_repo" add lazy-lock.json
  git -C "$source_repo" -c commit.gpgsign=false commit -q -m "$1"
  git -C "$source_repo" push -q origin main
}

local_commit() {
  echo "$1" > "$config/lazy-lock.json"
  git -C "$config" add lazy-lock.json
  git -C "$config" -c commit.gpgsign=false commit -q -m "$1"
}

@test "shared sync fast-forwards an existing checkout" {
  upstream_commit upstream
  run sync_checkout
  [ "$status" -eq 0 ]
  [ "$(git -C "$config" rev-parse HEAD)" = "$(git -C "$source_repo" rev-parse HEAD)" ]
}

@test "shared sync preserves local commits ahead of origin" {
  local_commit local
  before=$(git -C "$config" rev-parse HEAD)
  run sync_checkout
  [ "$status" -eq 0 ]
  [ "$(git -C "$config" rev-parse HEAD)" = "$before" ]
}

@test "shared sync refuses divergent histories without changing local HEAD" {
  local_commit local
  before=$(git -C "$config" rev-parse HEAD)
  upstream_commit upstream
  run sync_checkout
  [ "$status" -ne 0 ]
  [[ "$output" == *'diverged'* ]]
  [ "$(git -C "$config" rev-parse HEAD)" = "$before" ]
}

@test "only bootstrap can continue offline with an existing checkout" {
  mv "$remote" "$remote.offline"
  before=$(git -C "$config" rev-parse HEAD)
  run sync_checkout --allow-offline
  [ "$status" -eq 0 ]
  [ "$(git -C "$config" rev-parse HEAD)" = "$before" ]

  run sync_checkout
  [ "$status" -ne 0 ]
  [[ "$output" == *'Could not fetch'* ]]
}

@test "bootstrap uses one headless session with an isolated lock and cache" {
  cat > "$BATS_TEST_TMPDIR/mise" <<'MISE'
#!/usr/bin/env bash
set -eu
[[ "$*" == *"--headless"* ]]
[[ "$DOTFILES_NVIM_LOCK" != "$DOTFILES_NVIM_CONFIG/lazy-lock.json" ]]
[[ "$XDG_CACHE_HOME" == *dotfiles-nvim* ]]
cmp "$DOTFILES_NVIM_ORIGINAL" "$DOTFILES_NVIM_LOCK"
printf 'one\n' >> "$CALL_LOG"
printf 'changed copy\n' > "$DOTFILES_NVIM_LOCK"
touch "$DOTFILES_NVIM_SUCCESS"
MISE
  chmod +x "$BATS_TEST_TMPDIR/mise"
  export CALL_LOG="$BATS_TEST_TMPDIR/calls"
  run bash -c 'source "$1"; source "$2"; nvim_bootstrap_plugins "$3" "$4" "$(dirname "$2")"' \
    _ "$COMMON" "$NVIM" "$BATS_TEST_TMPDIR/mise" "$config"
  [ "$status" -eq 0 ]
  [ "$(cat "$CALL_LOG")" = one ]
  [ "$(cat "$config/lazy-lock.json")" = '{}' ]
}

@test "failed Neovim bootstrap restores the original lockfile" {
  cat > "$BATS_TEST_TMPDIR/mise" <<'MISE'
#!/usr/bin/env bash
printf 'modified\n' > "$DOTFILES_NVIM_CONFIG/lazy-lock.json"
exit 1
MISE
  chmod +x "$BATS_TEST_TMPDIR/mise"
  run bash -c 'source "$1"; source "$2"; nvim_bootstrap_plugins "$3" "$4" "$(dirname "$2")"' \
    _ "$COMMON" "$NVIM" "$BATS_TEST_TMPDIR/mise" "$config"
  [ "$status" -ne 0 ]
  [ "$(cat "$config/lazy-lock.json")" = '{}' ]
}

@test "bootstrap refuses a zero exit without plugin and parser verification" {
  printf '#!/usr/bin/env bash\nexit 0\n' > "$BATS_TEST_TMPDIR/mise"
  chmod +x "$BATS_TEST_TMPDIR/mise"
  run bash -c 'source "$1"; source "$2"; nvim_bootstrap_plugins "$3" "$4" "$(dirname "$2")"' \
    _ "$COMMON" "$NVIM" "$BATS_TEST_TMPDIR/mise" "$config"
  [ "$status" -ne 0 ]
  [[ "$output" == *'did not reach verification'* ]]
}
