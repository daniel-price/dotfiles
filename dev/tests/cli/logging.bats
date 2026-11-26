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
  [[ "$output" != *'expected failure'* ]]
  [[ "$output" == *'Log:'* ]]
  log=$(find "$STATE/dotfiles/logs" -type f -print -quit)
  grep -q 'expected failure' "$log"
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
  run env XDG_STATE_HOME="$STATE" DOTFILES_GUM=/not/a/gum bash -c '
    set -euo pipefail
    source "$1"
    run_step "Noninteractive" bash -c "echo plain command"
  ' _ "$LOGGING"
  [ "$status" -eq 0 ]
  [[ "$output" != *Noninteractive...* ]]
  [ "$output" = "✓ Noninteractive" ]
  [[ "$output" == *'✓ Noninteractive'* ]]
}

@test "failure diagnostics exclude previous successful step output" {
  run env XDG_STATE_HOME="$STATE" bash -c '
    set -euo pipefail
    source "$1"
    run_step "First" echo previous-step-output
    run_step "Second" bash -c "echo current-failure; exit 9"
  ' _ "$LOGGING"
  [ "$status" -eq 9 ]
  [[ "$output" != *previous-step-output* ]]
  [[ "$output" != *current-failure* ]]
  log=$(find "$STATE/dotfiles/logs" -type f -print -quit)
  grep -q 'current-failure' "$log"
  [[ "$output" == *'✗ Second'* ]]
}

@test "log permissions are private under a permissive umask" {
  run env XDG_STATE_HOME="$STATE" bash -c '
    umask 000
    source "$1"
    run_step "First" echo example
    ls -ld "$XDG_STATE_HOME/dotfiles/logs" "$DOTFILES_LOG_FILE"
  ' _ "$LOGGING"
  [ "$status" -eq 0 ]
  [[ "$output" == *drwx------* ]]
  [[ "$output" == *-rw-------* ]]
}

@test "spinner failure cannot replay an already started operation" {
  fake="$BATS_TEST_TMPDIR/gum"
  cat >"$fake" <<'SH'
#!/usr/bin/env bash
exit 23
SH
  chmod +x "$fake"
  counter="$BATS_TEST_TMPDIR/counter"
  run env XDG_STATE_HOME="$STATE" DOTFILES_GUM="$fake" bash -c '
    set -euo pipefail
    source "$1"
    logging_init
    logging_spin "Example" bash -c "echo once >> \"\$1\"; exit 7" _ "$2"
  ' _ "$LOGGING" "$counter"
  [ "$status" -eq 7 ]
  [ "$(cat "$counter")" = once ]
  [[ "$output" == *'Gum spinner failed'* ]]
}

@test "spinner success does not mask a worker failure" {
  fake="$BATS_TEST_TMPDIR/gum"
  cat >"$fake" <<'SH'
#!/usr/bin/env bash
while [[ "$1" != -- ]]; do shift; done
shift
"$@"
exit 0
SH
  chmod +x "$fake"
  run env XDG_STATE_HOME="$STATE" DOTFILES_GUM="$fake" bash -c '
    set -euo pipefail
    source "$1"
    logging_init
    logging_spin "Example" bash -c "exit 17"
  ' _ "$LOGGING"
  [ "$status" -eq 17 ]
}

@test "a terminal uses the available spinner and prints one permanent result" {
  # util-linux script allocates a PTY; macOS has a different CLI.
  [[ "$(uname -s)" == Linux ]] || skip "Linux PTY fixture"
  command -v script >/dev/null || skip "script not installed"
  fake="$BATS_TEST_TMPDIR/gum"
  cat >"$fake" <<'SH'
#!/usr/bin/env bash
[[ "$1" == spin && "$2" == --title ]] || exit 5
printf '%s\n' "$3" >"$SPINNER_TRACE"
shift 4
"$@"
SH
  chmod +x "$fake"
  runner="$BATS_TEST_TMPDIR/runner"
  cat >"$runner" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
source "$LOGGING"
run_step "TTY task" bash -c "sleep 0.2; echo hidden"
SH
  chmod +x "$runner"
  run env TERM=xterm XDG_STATE_HOME="$STATE" DOTFILES_GUM="$fake" \
    LOGGING="$LOGGING" SPINNER_TRACE="$BATS_TEST_TMPDIR/spinner" \
    script -q -e -c "$runner" /dev/null
  [ "$status" -eq 0 ]
  [ "$(cat "$BATS_TEST_TMPDIR/spinner")" = "TTY task" ]
  [[ "$output" == *'✓ TTY task'* ]]
  [[ "$output" != *hidden* ]]
  [ "$(grep -c 'TTY task' <<<"$output")" -eq 1 ]
}

@test "bootstrap logging and previews do not print raw output in quiet mode" {
  run env XDG_STATE_HOME="$STATE" DOTFILES_VERBOSE=false bash -c '
    set -euo pipefail
    source "$1"
    source "$2"
    logging_init
    log "routine info"
    preview_step bash -c "echo package-plan; echo preview-warning >&2"
    run_step "Installing packages" bash -c "echo package-output"
    report_error "example error"
  ' _ "$BATS_TEST_DIRNAME/../../../src/lib/common.sh" "$LOGGING"
  [ "$status" -eq 0 ]
  [[ "$output" != *routine* ]]
  [[ "$output" != *package-plan* ]]
  [[ "$output" != *preview-warning* ]]
  [[ "$output" != *package-output* ]]
  [[ "$output" == *'✓ Installing packages'* ]]
  [[ "$output" == *'✗ example error'* ]]
  log=$(find "$STATE/dotfiles/logs" -type f -print -quit)
  grep -q 'routine info' "$log"
  grep -q 'package-plan' "$log"
  grep -q 'package-output' "$log"
}
