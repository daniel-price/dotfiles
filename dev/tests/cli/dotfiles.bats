#!/usr/bin/env bats

setup() {
  COMMON="$BATS_TEST_DIRNAME/../../../src/lib/common.sh"
  DOTFILES="$BATS_TEST_DIRNAME/../../../src/lib/dotfiles.sh"
  export HOME="$BATS_TEST_TMPDIR/home"
  export ACTION_LOG="$BATS_TEST_TMPDIR/actions"
  export FAKE_SOURCE="$BATS_TEST_TMPDIR/source"
  export FAKE_FINAL_STATUS=0
  export APPROVE_CONFLICTS=0
  export FAKE_ROWS=''
  mkdir -p "$HOME/.config/zellij"
  printf 'managed\n' >"$FAKE_SOURCE"
  : >"$ACTION_LOG"

  MISE="$BATS_TEST_TMPDIR/mise"
  cat >"$MISE" <<'SH'
#!/usr/bin/env bash
set -eu
if [[ "$3" == dot && "$4" == status && "${5:-}" == --json ]]; then
  printf '{"files":[]}\n'
elif [[ "$3" == exec && "$4" == -- && "$5" == jq ]]; then
  cat >/dev/null
  while IFS=$'\t' read -r state target; do
    case "$state" in
      missing | differs | source_missing | applied) printf '%s\tsymlink\t%s\n' "$state" "$target" ;;
    esac
  done <<<"$FAKE_ROWS"
elif [[ "$3" == dot && "$4" == apply ]]; then
  target="${@: -1}"
  if [[ "$5" == --dry-run ]]; then
    # Mise may repoint an existing symlink without --force.
    printf 'preview:%s\n' "$target" >>"$ACTION_LOG"
  elif [[ "$5" == --yes ]]; then
    printf 'apply:%s\n' "$target" >>"$ACTION_LOG"
    mkdir -p "$(dirname "$target")"
    ln -s "$FAKE_SOURCE" "$target"
  else
    exit 2
  fi
elif [[ "$3" == dot && "$4" == status && "${5:-}" == --missing ]]; then
  exit "$FAKE_FINAL_STATUS"
else
  exit 2
fi
SH
  chmod +x "$MISE"
}

run_dotfiles() {
  bash -c 'source "$1"; source "$2"; confirm() { [[ "$1" != *"conflicting dotfile"* ]] || [[ "$APPROVE_CONFLICTS" == 1 ]]; }; apply_reviewed_dotfiles "$3"' \
    _ "$COMMON" "$DOTFILES" "$MISE"
}

@test "foreign Zellij symlink is preserved while missing Zsh config is applied" {
  ln -s "$BATS_TEST_TMPDIR/foreign" "$HOME/.config/zellij/config.kdl"
  export FAKE_ROWS
  FAKE_ROWS=$(printf 'differs\t%s\nmissing\t%s\n' \
    "$HOME/.config/zellij/config.kdl" "$HOME/.zshrc")
  export FAKE_FINAL_STATUS=1

  run run_dotfiles
  [ "$status" -ne 0 ]
  [[ "$output" == *'Skipped conflicting dotfile'* ]]
  [ "$(readlink "$HOME/.config/zellij/config.kdl")" = "$BATS_TEST_TMPDIR/foreign" ]
  [ -L "$HOME/.zshrc" ]
  ! grep -q "apply:$HOME/.config/zellij/config.kdl" "$ACTION_LOG"
  grep -q "apply:$HOME/.zshrc" "$ACTION_LOG"
}

@test "missing dotfiles are applied successfully" {
  export FAKE_ROWS
  FAKE_ROWS=$(printf 'missing\t%s\n' "$HOME/.zshrc")

  run run_dotfiles
  [ "$status" -eq 0 ]
  [ -L "$HOME/.zshrc" ]
}

@test "existing regular Zellij config is backed up before applying" {
  export APPROVE_CONFLICTS=1
  printf 'original\n' >"$HOME/.config/zellij/config.kdl"
  export FAKE_ROWS
  FAKE_ROWS=$(printf 'differs\t%s\n' "$HOME/.config/zellij/config.kdl")

  run run_dotfiles
  [ "$status" -eq 0 ]
  [ -L "$HOME/.config/zellij/config.kdl" ]
  backups=("$HOME"/.config/zellij/config.kdl.backup-*)
  [ "${#backups[@]}" -eq 1 ]
  [ "$(cat "${backups[0]}")" = original ]
}

@test "approved foreign symlink is backed up before replacement" {
  export APPROVE_CONFLICTS=1
  ln -s "$BATS_TEST_TMPDIR/foreign" "$HOME/.config/zellij/config.kdl"
  export FAKE_ROWS
  FAKE_ROWS=$(printf 'differs\t%s\n' "$HOME/.config/zellij/config.kdl")

  run run_dotfiles
  [ "$status" -eq 0 ]
  [ "$(readlink "$HOME/.config/zellij/config.kdl")" = "$FAKE_SOURCE" ]
  backups=("$HOME"/.config/zellij/config.kdl.backup-*)
  [ "${#backups[@]}" -eq 1 ]
  [ "$(readlink "${backups[0]}")" = "$BATS_TEST_TMPDIR/foreign" ]
}

@test "stale symlink reported applied by mise is backed up and repaired" {
  export APPROVE_CONFLICTS=1
  export FAKE_ROWS
  # The logical destination is correct, but the removed intermediate
  # directory makes this old symlink impossible to resolve.
  ln -s "$BATS_TEST_TMPDIR/old/setup/../../source" "$HOME/.zshrc"
  [ ! -e "$HOME/.zshrc" ]
  FAKE_ROWS=$(printf 'applied\t%s\n' "$HOME/.zshrc")

  run run_dotfiles
  [ "$status" -eq 0 ]
  [[ "$output" == *"Broken mise-managed symlink:"* ]]
  [ -L "$HOME/.zshrc" ]
  [ -e "$HOME/.zshrc" ]
  [ "$(readlink "$HOME/.zshrc")" = "$FAKE_SOURCE" ]
  backups=("$HOME"/.zshrc.backup-*)
  [ "${#backups[@]}" -eq 1 ]
  [ "$(readlink "${backups[0]}")" = "$BATS_TEST_TMPDIR/old/setup/../../source" ]
}

@test "declining repair of stale applied symlink fails bootstrap" {
  export FAKE_ROWS
  ln -s "$BATS_TEST_TMPDIR/old/setup/../../source" "$HOME/.zshrc"
  FAKE_ROWS=$(printf 'applied\t%s\n' "$HOME/.zshrc")

  run run_dotfiles
  [ "$status" -ne 0 ]
  [[ "$output" == *"Mise-managed symlink is still broken:"* ]]
  [ "$(readlink "$HOME/.zshrc")" = "$BATS_TEST_TMPDIR/old/setup/../../source" ]
  ! grep -q '^apply:' "$ACTION_LOG"
}

@test "fully applied dotfiles need no changes (including Bash 3.2)" {
  export FAKE_ROWS
  FAKE_ROWS=$(printf 'applied\t%s\n' "$HOME/.zshrc")

  run run_dotfiles
  [ "$status" -eq 0 ]
  [ ! -s "$ACTION_LOG" ]
}
