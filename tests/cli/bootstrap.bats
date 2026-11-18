#!/usr/bin/env bats

setup() {
  BOOTSTRAP="$BATS_TEST_DIRNAME/../../bin/,bootstrap"
}

@test "bootstrap help is available without provisioning" {
  run "$BOOTSTRAP" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *'Usage: ,bootstrap'* ]]
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
