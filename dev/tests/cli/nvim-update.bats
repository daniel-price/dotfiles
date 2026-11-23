#!/usr/bin/env bats

setup() {
  UPDATE="$BATS_TEST_DIRNAME/../../../bin/,nvim-update"
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME/.config/nvim" "$BATS_TEST_TMPDIR/bin"
  export HOME="$(cd "$HOME" && pwd -P)"
  config="$HOME/.config/nvim"
  git -C "$config" init -q -b main
  git -C "$config" config user.name Test
  git -C "$config" config user.email test@example.invalid
  printf '{}\n' > "$config/lazy-lock.json"
  git -C "$config" add lazy-lock.json
  git -C "$config" -c commit.gpgsign=false commit -q -m initial
  git -C "$config" remote add origin https://github.com/daniel-price/lazyvim.git
  cat > "$BATS_TEST_TMPDIR/bin/mise" <<'MISE'
#!/usr/bin/env bash
exit 0
MISE
  chmod +x "$BATS_TEST_TMPDIR/bin/mise"
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

@test "update has a read-only help path" {
  run "$UPDATE" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *'Usage: ,nvim-update'* ]]
}

@test "update refuses a foreign Neovim directory" {
  rm -rf "$config/.git"
  run "$UPDATE"
  [ "$status" -ne 0 ]
  [[ "$output" == *'not the expected Git checkout'* ]]
}

@test "update refuses an unexpected origin" {
  git -C "$config" remote set-url origin https://example.invalid/other.git
  run "$UPDATE"
  [ "$status" -ne 0 ]
  [[ "$output" == *'Unexpected LazyVim origin'* ]]
}

@test "update refuses uncommitted changes" {
  echo '# local change' >> "$config/lazy-lock.json"
  run "$UPDATE"
  [ "$status" -ne 0 ]
  [[ "$output" == *'uncommitted changes'* ]]
}

@test "update refuses non-main branches" {
  git -C "$config" switch -q -c feature/test
  run "$UPDATE"
  [ "$status" -ne 0 ]
  [[ "$output" == *'must be on main'* ]]
}

@test "update cannot proceed on redirected stdin" {
  run "$UPDATE"
  [ "$status" -eq 0 ]
  [[ "$output" == *'No changes made'* ]]
  [ -z "$(git -C "$config" status --porcelain --untracked-files=all)" ]
  [ "$(git -C "$config" rev-list --count HEAD)" -eq 1 ]
}
