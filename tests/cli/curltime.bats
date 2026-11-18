#!/usr/bin/env bats

setup() {
  CURLTIME="$BATS_TEST_DIRNAME/../../bin/,curltime"
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  export CURL_ARGS="$BATS_TEST_TMPDIR/curl-args"
  export CURL_EXIT=""
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
  cat > "$BATS_TEST_TMPDIR/bin/curl" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$CURL_ARGS"
if [[ -n "$CURL_EXIT" ]]; then
  exit "$CURL_EXIT"
fi
printf 'timings from fake curl\n'
STUB
  chmod +x "$BATS_TEST_TMPDIR/bin/curl"
}

@test "requires a URL or other curl arguments" {
  run "$CURLTIME"
  [ "$status" -eq 2 ]
  [[ "$output" == *'Usage: ,curltime'* ]]
  [ ! -e "$CURL_ARGS" ]
}

@test "passes arguments containing spaces to curl without splitting" {
  run "$CURLTIME" --header "X-Demo: two words" https://example.invalid
  [ "$status" -eq 0 ]
  [ "$output" = 'timings from fake curl' ]
  grep -Fxq -- '--show-error' "$CURL_ARGS"
  grep -Fxq -- '--write-out' "$CURL_ARGS"
  grep -Fxq -- 'X-Demo: two words' "$CURL_ARGS"
  grep -Fxq -- 'https://example.invalid' "$CURL_ARGS"
}

@test "propagates curl failures" {
  export CURL_EXIT=22
  run "$CURLTIME" https://example.invalid
  [ "$status" -eq 22 ]
  grep -Fxq -- 'https://example.invalid' "$CURL_ARGS"
}
