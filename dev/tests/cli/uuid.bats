#!/usr/bin/env bats

setup() {
  UUID="$BATS_TEST_DIRNAME/../../../src/bin/,uuid"
}

@test "help comes from argc annotations" {
  run "$UUID" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *'--lowercase'* ]] || { echo "Unexpected help: $output" >&3; false; }
  [[ "$output" == *'--no-hyphens'* ]]
}

@test "generates a UUID with both documented flags" {
  run "$UUID" --lowercase --no-hyphens
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^[0-9a-f]{32}$ ]]
}

@test "short flags preserve compact lowercase output" {
  run "$UUID" -l -n
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^[0-9a-f]{32}$ ]]
}

@test "default UUID retains its canonical hyphens" {
  run "$UUID"
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]
}

@test "rejects unexpected flags and positional arguments" {
  run "$UUID" --not-real
  [ "$status" -ne 0 ]
  run "$UUID" unexpected
  [ "$status" -ne 0 ]
}

@test "argc exports metadata and generates completion from the same script" {
  run argc --argc-export "$UUID"
  [ "$status" -eq 0 ]
  [[ "$output" == *'lowercase'* ]]
  [[ "$output" == *'no-hyphens'* ]]
  run argc --argc-completions zsh ,uuid
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}
