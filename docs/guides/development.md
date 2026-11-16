# Develop this repository

Shell scripts use shfmt for formatting and ShellCheck for linting. Lefthook
runs them before commits and preserves partial staging. These are development
tools for this checkout; the machine bootstrap does not install them.

## Set up once per checkout

Use macOS or Pop!_OS/Ubuntu-derived Linux with Git, Bash 3.2+ and
[mise](https://mise.jdx.dev/installing-mise.html) on `PATH`. The supported mise
version for this workflow is **2026.11.9**, also pinned in CI. Start in the
repository root and review `mise.toml` and `lefthook.yml` before trusting them.

Run each command deliberately: trust applies to this checkout, each install
downloads the named pinned tool into mise's tool storage, and the final step
asks before writing the checkout's Git hook.

```sh
mise trust mise.toml
mise install lefthook
mise install shfmt
mise install shellcheck
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
| `mise run check` | Check every tracked `*.sh` file without rewriting or staging it. |
| `mise run format` | Format every tracked `*.sh` file without changing staging. |
| `mise run test:hooks` | Exercise the hooks in a disposable repository that is removed afterwards. |
| `bash tests/run.sh` | Run the existing bootstrap checks; Python 3 enables the interactive cases. |

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

The **Shell checks** workflow installs the pinned tools, runs `mise run check`,
exercises real commits and partial staging, and runs the bootstrap tests on
Linux and macOS. CI uses the separate read-only check rather than the
auto-formatting commit hook. Local hook installation remains opt-in.
