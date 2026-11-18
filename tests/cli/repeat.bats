#!/usr/bin/env bats

setup() {
  REPEAT="$BATS_TEST_DIRNAME/../../bin/,repeat"
  export REPEAT_LOG="$BATS_TEST_TMPDIR/repeat.log"
}

@test "rejects missing arguments" {
  run "$REPEAT"
  [ "$status" -eq 2 ]
  [[ "$output" == *'Usage: ,repeat'* ]]
}

@test "rejects invalid iteration counts" {
  for count in 0 -1 abc; do
    run "$REPEAT" "$count" true
    [ "$status" -eq 2 ]
    [[ "$output" == *'Usage: ,repeat'* ]]
  done
}

@test "runs the requested number of times and preserves spaced arguments" {
  run "$REPEAT" 3 bash -c 'printf "%s\n" "$1" >> "$REPEAT_LOG"' _ 'hello world'
  [ "$status" -eq 0 ]
  [[ "$output" == *'Finished: 3 succeeded; 0 failed;'* ]]
  [ "$(grep -Fxc -- 'hello world' "$REPEAT_LOG")" -eq 3 ]
}

@test "runs all iterations despite command failures and returns failure" {
  run "$REPEAT" 3 bash -c 'printf x >> "$REPEAT_LOG"; exit 3'
  [ "$status" -eq 1 ]
  [[ "$output" == *'Finished: 0 succeeded; 3 failed;'* ]]
  [ "$(wc -c < "$REPEAT_LOG" | tr -d ' ')" -eq 3 ]
}
