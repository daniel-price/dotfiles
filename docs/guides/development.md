# Develop this repository

Shell scripts use shfmt for formatting and ShellCheck for linting. Lefthook
runs them before commits and preserves partial staging. These are development
tools for this checkout; the machine bootstrap does not install them.

## Set up once per checkout

Use macOS or Pop!_OS/Ubuntu-derived Linux with Git, Bash 3.2+ and
[mise](https://mise.jdx.dev/installing-mise.html) on `PATH`. The supported mise
version for this workflow is **2026.11.9**, also pinned in CI. Start in the
repository root and review `mise.toml` and `lefthook.yml` before trusting them.

Run each command deliberately: trust applies to this checkout, tool installation
downloads the declared pinned tools into mise's tool storage, and the final step
asks before writing the checkout's Git hook.

```sh
mise trust mise.toml
bash scripts/install-dev-tools.sh
mise run hooks:install
```

Answer `y` to enable the hook. The default answer is no; piped answers and
noninteractive input cannot approve installation. Repeating setup skips an
already-installed hook. Existing unrelated hooks, symlinked hooks and a
configured `core.hooksPath` are refused so you can resolve the conflict yourself.

The root `mise.toml` pins development tools and tasks. It is separate from
`.config/mise/config.toml`, the future managed global configuration. Automatic
tool installation is disabled in this checkout: use `mise install` explicitly
when installing missing tools or adopting a reviewed version change.

## Everyday commands

| Command | Result |
| --- | --- |
| `git commit` | Format staged `*.sh` files, stage the formatting, then run ShellCheck. |
| `bash scripts/format.sh` | Format every tracked `*.sh` file without changing staging. |
| `bash scripts/format.sh --check` | Check formatting without rewriting or staging files. |
| `bash scripts/lint.sh` | Run ShellCheck on every tracked `*.sh` file without changing it. |
| `bash scripts/format.sh -- file.sh` | Format selected files, using the same command as the commit hook. |
| `bash scripts/lint.sh -- file.sh` | Lint selected files, using the same command as the commit hook. |
| `bash tests/hooks.sh` | Exercise the hooks in a disposable repository that is removed afterwards. |
| `bash tests/run.sh` | Run the existing bootstrap checks; Python 3 enables the interactive cases. |
| `bash scripts/check-clean.sh` | Fail if tracked working files or the index differ from HEAD. |

`mise run format` and `mise run lint` are convenience aliases for these scripts.
`mise run check` runs both the formatting check and linting, reporting failures
from either command. `mise run test:hooks` runs the disposable hook tests.

Both scripts accept an optional file list after `--`; without one they select
tracked `*.sh` files. Combine `--check` with a file list to check selected files:
`bash scripts/format.sh --check -- file.sh`. Paths are relative to the repository
root, and names containing spaces are supported. The scripts can be invoked
from another directory by passing their full path. Shared file selection lives
in `scripts/lib/shell-files.sh`.

Lefthook runs through mise even when Git is launched from a shell without mise
activation, so the `mise` executable must be on that application's `PATH`.
The formatter and linter run sequentially on commit to avoid reading a file
while the formatter is changing it. ShellCheck errors block the commit.

For partially staged files, Lefthook hides the unstaged edits, formats the
staged version, stages the result, and restores the unstaged edits. shfmt
formats the whole staged file, so existing formatting elsewhere in it can also
change. A conflict while restoring unstaged edits can abort the commit;
inspect the reported recovery information before retrying.

Only tracked files ending in `.sh` are selected. Zsh configuration and
extensionless scripts are outside this selection; ShellCheck does not support
zsh. Add an appropriate separate check when those files are introduced.

## Continuous validation

The **Shell checks** workflow installs the pinned tools, runs
`bash scripts/format.sh --check` and `bash scripts/lint.sh`, exercises real
commits and partial staging, and runs the bootstrap tests on Linux and macOS.
These CI commands are read-only. Local hook installation remains opt-in.

Workflow `run` steps contain script calls. Scripts own the tool invocations,
arguments and validation so local runs and hooks share the same behaviour.
Actions handle runtime provisioning, caches, artifact upload and deployment.

## Build the documentation locally

Use Python 3.13, as in the documentation workflow. Create and activate a virtual
environment before installing dependencies, then call the same scripts as CI:

```sh
docs_env=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-docs.XXXXXX")
python3 -m venv "$docs_env"
. "$docs_env/bin/activate"
bash scripts/install-docs-deps.sh
bash scripts/build-docs.sh
deactivate
rm -rf -- "$docs_env"
```

The strict build writes the ignored `site/` directory and exits nonzero for
documentation errors. The final two commands remove the temporary Python
environment. The build script can also be called from a Git hook.
