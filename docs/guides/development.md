# Development

```sh
bash dev/scripts/run-mise.sh trust mise.toml
bash dev/scripts/install-dev-tools.sh
```

## Commands

| Command | Action |
| --- | --- |
| `mise -C dev run check` | All checks |
| `mise -C dev run format` | Format |
| `mise -C dev run test` | Tests |
| `bash dev/scripts/test-bats.sh` | Bats tests |
| `bash dev/scripts/install-hooks.sh` | Git hooks |

## Conventions

- Bats for standalone CLI tests; Python for PTY integration tests.
- Argc annotations for supported CLI arguments and completions.
- Generate references from configuration and CLI metadata.

## Documentation

```sh
python3 -m venv .venv-docs
. .venv-docs/bin/activate
bash dev/scripts/install-docs-deps.sh
bash dev/scripts/run-mise.sh install argc
bash dev/scripts/build-docs.sh
```
