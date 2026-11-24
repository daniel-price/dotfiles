#!/usr/bin/env bats

setup() {
  BOOTSTRAP="$BATS_TEST_DIRNAME/../../../bin/,bootstrap"
}

@test "bootstrap help is available without provisioning" {
  for flag in -h --help; do
    run "$BOOTSTRAP" "$flag"
    [ "$status" -eq 0 ]
    [[ "$output" == *'Usage: ,bootstrap'* ]]
  done
}

@test "bootstrap rejects unexpected options" {
  run "$BOOTSTRAP" --unknown
  [ "$status" -ne 0 ]
  [[ "$output" == *'Unknown argument'* ]]
}

@test "bootstrap rejects extra help arguments" {
  run "$BOOTSTRAP" --help extra
  [ "$status" -ne 0 ]
  [[ "$output" == *'Unexpected extra argument'* ]]
}

@test "concise command output preserves diagnostics and exit status" {
  run bash -c 'source "$1"; DOTFILES_VERBOSE=false; run_concise bash -c "echo routine; echo WARNING: example; exit 0"' _ "$BATS_TEST_DIRNAME/../../../lib/common.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"WARNING: example"* ]]
  [[ "$output" != *routine* ]]
  run bash -c 'source "$1"; DOTFILES_VERBOSE=false; run_concise bash -c "echo failed; exit 7"' _ "$BATS_TEST_DIRNAME/../../../lib/common.sh"
  [ "$status" -eq 7 ]
  [[ "$output" == *failed* ]]
  run bash -c 'source "$1"; DOTFILES_VERBOSE=true; run_concise echo routine' _ "$BATS_TEST_DIRNAME/../../../lib/common.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *routine* ]]
}
