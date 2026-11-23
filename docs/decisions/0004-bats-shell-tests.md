# ADR-0004: Use Bats-core for standalone shell CLI behaviour

**Status:** Accepted
**Date:** 2026-11-18

## Context

Small standalone utilities need regression coverage for their arguments, stdout/stderr, exit statuses and side effects. A growing collection of shared Bash test helpers would amount to a custom testing framework and make failures harder to isolate. The repository already uses ShellCheck/shfmt for static checks and Python tests for interactive bootstrap and pseudo-terminal integration.

## Decision

Pin **Bats-core** in the checkout-only `dev/mise.toml` (never the machine manifest) and invoke it through `dev/scripts/test-bats.sh`. Store behavioural tests in `dev/tests/cli/<command>.bats`, with one file per utility and focused `@test` cases. Each test runs its command in an isolated, disposable fixture, asserts status and observable behaviour, and must not require external services or credentials.

Expose `mise -C dev run test:bats` for the Bats suite and `mise -C dev run test` for Bats plus the existing hook and integration checks. CI calls the same repository scripts rather than the test framework directly. Keep the existing Python process/PTY integration tests as Python; do not migrate them merely for uniformity.

Do not add assertion/mocking libraries until repeated cases justify their maintenance. Keep formatting and linting separate from behavioural tests; Bats files are run with Bats, not executed by a plain Bash syntax check.

## Alternatives

- **One hand-written Bash harness:** less tooling, but duplicates assertion and reporting machinery and couples unrelated utilities.
- **One test script per utility without a framework:** isolates files but leaves bespoke boilerplate.
- **ShellSpec:** a capable framework with more built-in behaviour; unnecessary complexity for small executable scripts.
- **Convert Python integration tests to Bats:** loses their already-useful process and terminal orchestration.

## Consequences

Bats is an additional pinned development dependency, installed only during explicit development setup. Test failures are scoped to individual `@test` cases; new CLI utilities should include their own Bats file, while interactive bootstrap fixtures remain in the existing test suites.
