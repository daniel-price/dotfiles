#!/usr/bin/env bats

setup() {
  COMMON="$BATS_TEST_DIRNAME/../../../lib/common.sh"
  DOTFILES="$BATS_TEST_DIRNAME/../../../lib/dotfiles.sh"
  export HOME="$BATS_TEST_TMPDIR/home"
  export ACTION_LOG="$BATS_TEST_TMPDIR/actions"
  export FAKE_SOURCE="$BATS_TEST_TMPDIR/source"
  export FAKE_FINAL_STATUS=0
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
  while IFS=
elif [[ "$3" == dot && "$4" == apply ]]; then
  target="${@: -1}"
  if [[ "$5" == --dry-run ]]; then
    # Mise rejects a foreign symlink unless explicitly forced.
    if [[ -L "$target" && "${6:-}" != --force ]]; then
      exit 17
    fi
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
  bash -c 'source "$1"; source "$2"; confirm() { return 0; }; apply_reviewed_dotfiles "$3"' \
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
  [[ "$output" == *'Dotfile conflict'* ]]
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

@test "fully applied dotfiles need no changes (including Bash 3.2)" {
  export FAKE_ROWS
  FAKE_ROWS=$(printf 'applied\t%s\n' "$HOME/.zshrc")

  run run_dotfiles
  [ "$status" -eq 0 ]
  [ ! -s "$ACTION_LOG" ]
}
\t' read -r state target; do
    case "$state" in
      missing | differs) printf '%s\n' "$target" ;;
    esac
  done <<<"$FAKE_ROWS"
elif [[ "$3" == dot && "$4" == apply ]]; then
  target="${@: -1}"
  if [[ "$5" == --dry-run ]]; then
    # Mise rejects a foreign symlink unless explicitly forced.
    if [[ -L "$target" && "${6:-}" != --force ]]; then
      exit 17
    fi
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
  bash -c 'source "$1"; source "$2"; confirm() { return 0; }; apply_reviewed_dotfiles "$3"' \
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
  [[ "$output" == *'Dotfile conflict'* ]]
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

@test "fully applied dotfiles need no changes (including Bash 3.2)" {
  export FAKE_ROWS
  FAKE_ROWS=$(printf 'applied\t%s\n' "$HOME/.zshrc")

  run run_dotfiles
  [ "$status" -eq 0 ]
  [ ! -s "$ACTION_LOG" ]
}
