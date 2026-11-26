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

## Manual branch or PR testing

On a machine with [rootless Podman](podman.md):

```sh
,test-env 107
,test-env feature/my-change
```

Each invocation builds or reuses the Ubuntu 24.04 test image, fetches the exact
public GitHub ref and opens a fresh container as a non-root user. The host home,
checkout and credentials are not mounted. Only Git, curl, CA certificates and
sudo are preinstalled. The test account can use sudo; if chsh asks for its
password, use `dotfiles` (a disposable test credential).

Inside the container:

```sh
bash src/bin/,bootstrap --no-update
zsh -l
```

Use `--no-update` to avoid switching to main. Exit Zsh and then the outer Bash
shell to remove the container; the reusable image remains. This tests Linux CLI
provisioning, not a Pop!_OS desktop, macOS, or nested Podman.

## Conventions

- Bats for standalone CLI tests; Python for PTY integration tests.
- Argc annotations for supported CLI arguments and completions.
- Generate references from configuration and CLI metadata.
- Source `src/lib/logging.sh` and call `run_step "Description" command args...` for non-interactive, non-secret work. Use `info`, `warn` and `error` for contextual messages; keep prompts, sudo and credential operations outside captured steps. Use `run_step --sensitive` only for non-interactive operations whose output must be discarded, even in verbose mode. `run_step` returns the command status; handle expected failures explicitly. `run_provision_step` preserves normal output in standalone setup helpers. Never wrap a pipeline that supplies data to the caller.

## Documentation

```sh
python3 -m venv .venv-docs
. .venv-docs/bin/activate
bash dev/scripts/install-docs-deps.sh
bash dev/scripts/run-mise.sh install argc
bash dev/scripts/build-docs.sh
```
