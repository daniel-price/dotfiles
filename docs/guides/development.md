# Develop this repository

Machine bootstrap and repo development use **different mise manifests**. The root deliberately has no `mise.toml`; the developer manifest lives at `dev/mise.toml`. To install checkout-only tools and optionally enable the pre-commit hook:

```sh
bash dev/scripts/run-mise.sh trust mise.toml
bash dev/scripts/install-dev-tools.sh
```

Review the manifest before trusting it. Existing conflicting hooks are preserved; installing the hook requires interactive approval.

## Useful commands

Run development tasks through mise from the repository root using `mise -C dev run check`, `mise -C dev run format`, or `mise -C dev run test`. The wrappers below remain available for scripts and CI.

| Command | Action |
| --- | --- |
| `bash dev/scripts/format.sh --check` | Check shell formatting |
| `bash dev/scripts/format.sh` | Format tracked shell scripts |
| `bash dev/scripts/lint.sh` | Run ShellCheck |
| `mise -C dev run test` or `bash dev/scripts/test.sh` | Run Bats CLI tests, hooks and integration checks |
| `bash dev/scripts/test-bats.sh` | Run all Bats CLI tests |
| `bash dev/scripts/test-bats.sh dev/tests/cli/bootstrap.bats` | Run one Bats file |
| `bash dev/scripts/run-mise.sh exec -- bash dev/tests/run.sh` | Run existing bootstrap/integration checks only |
| `bash dev/scripts/install-hooks.sh` | Offer pre-commit hook setup |
| `bash dev/scripts/check-clean.sh` | Check tracked checkout cleanliness |

## Shell behaviour tests

Use [Bats-core](https://github.com/bats-core/bats-core) for portable command behaviour. Create one `dev/tests/cli/<command>.bats` file per standalone CLI; each test runs the real command with disposable fixtures and checks both exit status and observable output. Use `run` to capture failures without aborting the suite. No live services, credentials or network access in unit tests.

Bats is pinned in the checkout-only `dev/mise.toml`, not the machine bootstrap manifest. Run `bash dev/scripts/install-dev-tools.sh` once after trusting the repo to install it. Keep the existing Python pseudo-terminal/integration tests rather than rewriting them into Bats. The conventions are recorded in [ADR-0004](../decisions/0004-bats-shell-tests.md).

The hook uses Lefthook to format and re-stage the staged version of a file before linting. Test partially staged changes carefully: formatting can affect other staged lines, and conflicting unstaged edits can interrupt restoration. CI calls the same scripts and tests on Linux/macOS.

## Argc-based commands

Small, standalone Bash CLIs can declare arguments using inline `# @flag`, `# @option` and `# @arg` comments. Argc 1.24.0 is pinned in both the development and machine mise manifests; machine bootstrap offers its installation with the usual explicit consent. Bootstrap itself does not depend on argc. The first converted command is `,uuid`; other commands retain their existing parsers.

On a machine with argc installed, run `,uuid --help` or type `,uuid --` and press Tab in interactive Zsh. Completions load only when argc is available. Edit the Bash annotations directly; there is **no per-edit compilation or generated-file commit**.

Markdown is generated from `argc --argc-export` as part of `bash dev/scripts/build-docs.sh` (the docs build requires the checkout's pinned argc). See the [generated argc command reference](argc.md) and [ADR-0005](../decisions/0005-argc-cli.md). Native argc man pages remain available for optional generation.

For additional command options, see the [generated CLI reference](cli.md).

## Build documentation locally

Use Python 3.13 in a virtual environment, and install the pinned development tools first:

```sh
python3 -m venv .venv-docs
. .venv-docs/bin/activate
bash dev/scripts/install-docs-deps.sh
bash dev/scripts/run-mise.sh install argc
bash dev/scripts/build-docs.sh
```

The strict build writes to ignored `site/`. Deactivate and remove `.venv-docs` when finished. GitHub Actions validates documentation on PRs and publishes main to Pages.
