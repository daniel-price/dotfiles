#!/usr/bin/env bats

setup() {
  UNTIL="$BATS_TEST_DIRNAME/../../../src/bin/,until-failure"
  export ATTEMPTS="$BATS_TEST_TMPDIR/attempts"
}

@test "rejects missing command" {
  run "$UNTIL"
  [ "$status" -eq 2 ]
  [[ "$output" == *'Usage: ,until-failure'* ]]
}

@test "propagates failure of the first attempt" {
  run "$UNTIL" bash -c 'exit 7'
  [ "$status" -eq 7 ]
  [[ "$output" == *'Failed after 0 successful run(s), exit status 7'* ]]
}

@test "stops after two successful attempts and preserves final failure status" {
  cat > "$BATS_TEST_TMPDIR/command" <<'COMMAND'
#!/usr/bin/env bash
attempt=0
if [[ -f "$ATTEMPTS" ]]; then
  read -r attempt < "$ATTEMPTS"
fi
attempt=$((attempt + 1))
printf '%s\n' "$attempt" > "$ATTEMPTS"
if (( attempt < 3 )); then
  exit 0
fi
exit 9
COMMAND
  chmod +x "$BATS_TEST_TMPDIR/command"
  run "$UNTIL" "$BATS_TEST_TMPDIR/command"
  [ "$status" -eq 9 ]
  [[ "$output" == *'Succeeded 2 time(s)'* ]]
  [[ "$output" == *'Failed after 2 successful run(s), exit status 9'* ]]
  [ "$(cat "$ATTEMPTS")" = 3 ]
}

@test "preserves command arguments containing spaces" {
  run "$UNTIL" bash -c '[[ "$1" == "two words" ]] || exit 8; exit 4' _ 'two words'
  [ "$status" -eq 4 ]
}
