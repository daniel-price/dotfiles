# Develop this repository

Machine bootstrap and repo development use **different mise manifests**. To install checkout-only tools and optionally enable the pre-commit hook:

```sh
bash scripts/dev/run-mise.sh trust mise.toml
bash scripts/dev/install-dev-tools.sh
```

Review the manifest before trusting it. Existing conflicting hooks are preserved; installing the hook requires interactive approval.

## Useful commands

| Command | Action |
| --- | --- |
| `bash scripts/dev/format.sh --check` | Check shell formatting |
| `bash scripts/dev/format.sh` | Format tracked shell scripts |
| `bash scripts/dev/lint.sh` | Run ShellCheck |
| `bash tests/run.sh` | Run bootstrap and integration checks |
| `bash scripts/dev/install-hooks.sh` | Offer pre-commit hook setup |
| `bash scripts/dev/check-clean.sh` | Check tracked checkout cleanliness |

The hook uses Lefthook to format and re-stage the staged version of a file before linting. Test partially staged changes carefully: formatting can affect other staged lines, and conflicting unstaged edits can interrupt restoration. CI calls the same scripts and tests on Linux/macOS.

For additional command options, see the [generated CLI reference](cli.md).

## Build documentation locally

Use Python 3.13 in a virtual environment:

```sh
python3 -m venv .venv-docs
. .venv-docs/bin/activate
bash scripts/dev/install-docs-deps.sh
bash scripts/dev/build-docs.sh
```

The strict build writes to ignored `site/`. Deactivate and remove `.venv-docs` when finished. GitHub Actions validates documentation on PRs and publishes main to Pages.
