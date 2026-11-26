#!/usr/bin/env bats

setup() {
  LOGGING="$BATS_TEST_DIRNAME/../../../src/lib/logging.sh"
  STATE="$BATS_TEST_TMPDIR/state"
}

@test "quiet steps print a status, keep command output private and preserve result" {
  run env XDG_STATE_HOME="$STATE" bash -c '
    set -euo pipefail
    source "$1"
    run_step "Installing Neovim" bash -c "echo noisy output"
  ' _ "$LOGGING"
  [ "$status" -eq 0 ]
  [[ "$output" == *'✓ Installing Neovim'* ]]
  [[ "$output" != *'noisy output'* ]]
  log=$(find "$STATE/dotfiles/logs" -type f -print -quit)
  [ -f "$log" ]
  grep -q 'noisy output' "$log"
}

@test "verbose steps stream output and retain their log" {
  run env XDG_STATE_HOME="$STATE" DOTFILES_VERBOSE=true bash -c '
    set -euo pipefail
    source "$1"
    run_step "Syncing tools" bash -c "echo detailed output"
  ' _ "$LOGGING"
  [ "$status" -eq 0 ]
  [[ "$output" == *'detailed output'* ]]
  [[ "$output" == *'✓ Syncing tools'* ]]
  log=$(find "$STATE/dotfiles/logs" -type f -print -quit)
  grep -q 'detailed output' "$log"
}

@test "failed step reports the exit code and log path" {
  run env XDG_STATE_HOME="$STATE" bash -c '
    set -euo pipefail
    source "$1"
    run_step "Broken tool" bash -c "echo expected failure; exit 7"
  ' _ "$LOGGING"
  [ "$status" -eq 7 ]
  [[ "$output" == *'Broken tool failed (exit 7)'* ]]
  [[ "$output" == *'expected failure'* ]]
  [[ "$output" == *'Full details:'* ]]
}

@test "sensitive steps do not disclose or record command output" {
  run env XDG_STATE_HOME="$STATE" DOTFILES_VERBOSE=true bash -c '
    set -euo pipefail
    source "$1"
    run_step --sensitive "Private operation" bash -c "echo never-print-this"
  ' _ "$LOGGING"
  [ "$status" -eq 0 ]
  [[ "$output" != *'never-print-this'* ]]
  [[ "$output" == *'✓ Private operation'* ]]
  if [ -d "$STATE/dotfiles/logs" ]; then
    ! grep -Rl 'never-print-this' "$STATE/dotfiles/logs"
  fi
}

@test "sensitive failures retain their exit status without logging output" {
  run env XDG_STATE_HOME="$STATE" bash -c '
    set -euo pipefail
    source "$1"
    run_step --sensitive "Private operation" bash -c "echo secret; exit 13"
  ' _ "$LOGGING"
  [ "$status" -eq 13 ]
  [[ "$output" != *secret* ]]
  [[ "$output" == *'Private operation failed (exit 13)'* ]]
}

@test "missing Gum and non-TTY mode use plain progress and still execute" {
  run env XDG_STATE_HOME="$STATE" DOTFILES_GUM_MISE=/not/a/mise bash -c '
    set -euo pipefail
    source "$1"
    run_step "Noninteractive" bash -c "echo plain command"
  ' _ "$LOGGING"
  [ "$status" -eq 0 ]
  [[ "$output" == *Noninteractive...* ]]
  [[ "$output" == *'✓ Noninteractive'* ]]
}
