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
  [[ "$output" != *'Gum spinner failed'* ]]
  log=$(find "$STATE/dotfiles/logs" -type f -print -quit)
  grep -q 'Gum spinner failed (exit 23)' "$log"
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
[[ "$4" == --spinner && "$5" == minidot && "$6" == --padding && "$7" == "0 0" ]] || exit 94
shift 8
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

@test "approved APT installation uses Gum after authenticating and never prompts in the spinner" {
  [[ "$(uname -s)" == Linux ]] || skip "Linux PTY fixture"
  command -v script >/dev/null || skip "script not installed"
  bin="$BATS_TEST_TMPDIR/bin"
  mkdir "$bin"
  cat >"$bin/sudo" <<'SH'
#!/usr/bin/env bash
printf 'sudo %s\n' "$*" >>"$TRACE"
[[ "$1" == -n ]] || exit 91
shift
if [[ "$1" == -v ]]; then exit 0; fi
"$@"
SH
  cat >"$bin/mise" <<'SH'
#!/usr/bin/env bash
printf 'mise %s\n' "$*" >>"$TRACE"
[[ "$*" == '-C / bootstrap packages apply --yes' ]] || exit 92
sudo bash -c 'sleep 0.2; echo raw-package-output'
SH
  cat >"$bin/gum" <<'SH'
#!/usr/bin/env bash
[[ "$1" == spin && "$2" == --title ]] || exit 93
printf 'spinner %s\n' "$3" >>"$TRACE"
[[ "$4" == --spinner && "$5" == minidot && "$6" == --padding && "$7" == "0 0" ]] || exit 94
shift 8
"$@"
SH
  chmod +x "$bin/"*
  runner="$BATS_TEST_TMPDIR/runner"
  cat >"$runner" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
source "$LIB/common.sh"
source "$LIB/logging.sh"
source "$LIB/mise.sh"
logging_init
install_reviewed_packages debian mise
SH
  chmod +x "$runner"
  run env TERM=xterm XDG_STATE_HOME="$STATE" DOTFILES_GUM="$bin/gum" \
    PATH="$bin:$PATH" LIB="$BATS_TEST_DIRNAME/../../../src/lib" \
    TRACE="$BATS_TEST_TMPDIR/trace" script -q -e -c "$runner" /dev/null
  [ "$status" -eq 0 ]
  [[ "$output" == *'✓ Installing OS packages'* ]]
  [[ "$output" != *'… Installing OS packages'* ]]
  [[ "$output" != *raw-package-output* ]]
  [ "$(grep -c 'Installing OS packages' <<<"$output")" -eq 1 ]
  [ "$(head -n 1 "$BATS_TEST_TMPDIR/trace")" = 'sudo -n -v' ]
  grep -qx 'spinner Installing OS packages' "$BATS_TEST_TMPDIR/trace"
  grep -q '^sudo -n bash -c ' "$BATS_TEST_TMPDIR/trace"
  [ "$(grep -c '^mise ' "$BATS_TEST_TMPDIR/trace")" -eq 1 ]
  log=$(find "$STATE/dotfiles/logs" -type f -print -quit)
  grep -q 'raw-package-output' "$log"
}

@test "fresh bootstrap uses an animated spinner before Gum is installed" {
  [[ "$(uname -s)" == Linux ]] || skip "Linux PTY fixture"
  command -v script >/dev/null || skip "script not installed"
  runner="$BATS_TEST_TMPDIR/runner"
  cat >"$runner" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
source "$LOGGING"
run_step "Installing mise" bash -c "sleep 0.4; echo private-output"
SH
  chmod +x "$runner"
  run env TERM=xterm XDG_STATE_HOME="$STATE" DOTFILES_GUM=/not/installed \
    LOGGING="$LOGGING" script -q -e -c "$runner" /dev/null
  [ "$status" -eq 0 ]
  [[ "$output" == *'⠋ Installing mise'* ]]
  [[ "$output" == *'⠙ Installing mise'* ]]
  [[ "$output" == *'✓ Installing mise'* ]]
  [[ "$output" != *private-output* ]]
}

@test "Gum cancellation stops the worker without falling back or replaying it" {
  fake="$BATS_TEST_TMPDIR/gum"
  cat >"$fake" <<'SH'
#!/usr/bin/env bash
sleep 0.2
exit 130
SH
  chmod +x "$fake"
  counter="$BATS_TEST_TMPDIR/counter"
  run env XDG_STATE_HOME="$STATE" DOTFILES_GUM="$fake" bash -c '
    set -euo pipefail
    source "$1"
    logging_init
    logging_spin "Example" bash -c "echo start >> \"\$1\"; sleep 2; echo finished >> \"\$1\"" _ "$2"
  ' _ "$LOGGING" "$counter"
  [ "$status" -eq 130 ]
  [ "$(cat "$counter")" = start ]
  log=$(find "$STATE/dotfiles/logs" -type f -print -quit)
  ! grep -q 'Gum spinner failed' "$log"
}

@test "confirmation replaces a wrapped prompt and retains declined status" {
  [[ "$(uname -s)" == Linux ]] || skip "Linux PTY fixture"
  command -v script >/dev/null || skip "script not installed"
  runner="$BATS_TEST_TMPDIR/confirm-runner"
  cat >"$runner" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
stty rows 24 cols 30
source "$LIB/common.sh"
source "$LIB/logging.sh"
logging_init
# Feed the input from the PTY after read has entered single-character mode.
if confirm "Install an example component with a long description?"; then
    printf '✓ Installed example\n'
fi
SH
  chmod +x "$runner"
  # script's input is supplied by a delayed pipe to avoid racing read -s.
  for decision in y n; do
    run bash -c '
      (sleep 0.3; printf "%s" "$1") | env TERM=xterm XDG_STATE_HOME="$2" \
        LIB="$3" script -q -e -c "$4" /dev/null
    ' _ "$decision" "$STATE" "$BATS_TEST_DIRNAME/../../../src/lib" "$runner"
    [ "$status" -eq 0 ]
    [[ "$output" == *$'\033[2K'* ]]
    [[ "$output" == *$'\033[1A'* ]]
    if [[ "$decision" == y ]]; then
      [[ "$output" == *'✓ Installed example'* ]]
      [[ "$output" != *'✗ Declined:'* ]]
    else
      [[ "$output" == *'✗ Declined: Install an example component with a long description'* ]]
      [[ "$output" != *'✓ Installed example'* ]]
    fi
  done
}

@test "spinner cleanup and final newline reset the cursor with terminal ONLCR disabled" {
  [[ "$(uname -s)" == Linux ]] || skip "Linux PTY fixture"
  command -v script >/dev/null || skip "script not installed"
  fake="$BATS_TEST_TMPDIR/gum"
  cat >"$fake" <<'SH'
#!/usr/bin/env bash
# Emulate a renderer leaving its cursor at the end of a padded line.
printf '⠋ %s          ' "$3"
while [[ "$1" != -- ]]; do shift; done
shift
"$@"
SH
  chmod +x "$fake"
  runner="$BATS_TEST_TMPDIR/runner"
  cat >"$runner" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
stty -onlcr
source "$LOGGING"
run_step "Installing first" sleep 0.2
run_step "Installing second" sleep 0.2
SH
  chmod +x "$runner"
  run env TERM=xterm XDG_STATE_HOME="$STATE" DOTFILES_GUM="$fake" \
    LOGGING="$LOGGING" script -q -e -c "$runner" /dev/null
  [ "$status" -eq 0 ]
  [[ "$output" == *$'\r\033[2K✓ Installing first\r\n⠋ Installing second'* ]]
  [[ "$output" == *$'\r\033[2K✓ Installing second\r'* ]]
}
