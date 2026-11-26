#!/usr/bin/env bats

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../../../src/bin/,test-env"
    export PODMAN_LOG="$BATS_TEST_TMPDIR/podman.log"
    export ROOTLESS=true
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    cat >"$BATS_TEST_TMPDIR/bin/podman" <<'SH'
#!/usr/bin/env bash
if [[ "$1" == info ]]; then
    printf '%s\n' "$ROOTLESS"
else
    printf '%s\n' "$@" >>"$PODMAN_LOG"
fi
SH
    chmod +x "$BATS_TEST_TMPDIR/bin/podman"
    export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

@test "PR number selects the GitHub pull request head" {
    run "$SCRIPT" 107
    [ "$status" -eq 0 ]
    grep -Fx 'refs/pull/107/head' "$PODMAN_LOG"
    grep -Fx -- '--rm' "$PODMAN_LOG"
    grep -Fx -- '--http-proxy=false' "$PODMAN_LOG"
    ! grep -Ex -- '(-v|--volume|--mount|--privileged|--env-host)(=.*)?' "$PODMAN_LOG"
}

@test "branch selects the exact remote branch" {
    run "$SCRIPT" feature/new-bootstrap
    [ "$status" -eq 0 ]
    grep -Fx 'refs/heads/feature/new-bootstrap' "$PODMAN_LOG"
}

@test "invalid ref is rejected before invoking Podman" {
    run "$SCRIPT" 'invalid branch'
    [ "$status" -ne 0 ]
    [ ! -e "$PODMAN_LOG" ]
}

@test "rootful Podman is refused before building or running" {
    export ROOTLESS=false
    run "$SCRIPT" 107
    [ "$status" -ne 0 ]
    [ ! -e "$PODMAN_LOG" ]
}
