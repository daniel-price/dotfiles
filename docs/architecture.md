# Architecture

## Two entry points, one small shared library

`bootstrap.sh` is the future fresh-machine path: detect the OS, ensure minimal
prerequisites, help with machine-specific SSH credentials, install mise, clone
this repository and delegate to `update.sh`.

`update.sh` is the future recurring path: synchronise the checkout, install
missing software, apply reviewed configuration, apply OS-specific settings and
report changes. Software upgrades will require a separate explicit operation.

Today both scripts only detect the platform and print their unimplemented scope.
Bootstrap does not invoke update yet. Each can run without mise, Git, an existing
shell configuration or network access when the checkout is already present.
Standalone acquisition of the shared files is a later bootstrap task.

The scripts use Bash 3.2-compatible syntax for the system Bash on macOS. They
resolve their libraries relative to their own location, use strict error handling
and reject unknown arguments. Libraries do not change caller options or traps.

`detect_os` returns `macos` for Darwin and `debian` for Debian/Ubuntu-derived Linux,
including Pop!_OS. It reads `ID` and `ID_LIKE` from `/etc/os-release`, with the
standard `/usr/lib/os-release` fallback, without executing the metadata. Other
platforms fail explicitly. Optional function arguments accept test fixtures;
the entry points always inspect the host. Detection chooses a family, not a
guarantee that apt or any other tool is installed.

## Ownership of future functionality

| Concern | Intended owner |
| --- | --- |
| Ordering, state checks and per-operation consent | Small Bash entry points and helpers |
| Development runtimes and suitable standalone tools | mise declarations |
| Linux system packages | apt on supported Debian-derived systems |
| macOS packages and applications | Homebrew on macOS only |
| Interactive shell | Zsh; bootstrap remains independent of its configuration |
| Dotfile deployment | Evaluate mise's native symlink support before adding Bash logic |
| Private settings and credentials | Machine-local files, outside version control |

Neovim, Zellij and Ghostty have directory markers, not usable configurations.
Deploy only explicitly reviewed targets; never link the whole `.config` directory
or marker-only application directories. No package lists, hooks, services,
deployment entries or installation tasks are declared in this scaffold.

## Consent and idempotency

For each future operation, inspect the current state, skip it if already correct,
describe the exact change, then call `confirm` immediately before the change.
Invoke the helper in an `if` condition so a declined action is an ordinary skip,
not an accidental strict-mode exit. It returns success only for explicit `y` or
`yes` from terminal stdin, and refuses pipes, empty input, invalid input and EOF.
There is no unattended approval flag.

Confirmation is required for each potentially modifying operation, including
fetches, downloads, backups, directory creation and sudo. One approval must not
authorise an entire batch of unrelated changes. Report skips, failures and actual
changes truthfully; an unimplemented step must never claim success.

Existing correct symlinks should be skipped. Existing files, different links and
directories are conflicts: show them and stop or obtain an explicit decision
before any backup or replacement. Never use force to bypass a conflict.
Idempotency checks are still required after an operation has been approved.

Future Git synchronisation must verify the repository and remote, guard dirty or
diverged work, and use a fast-forward-only policy. Fetch and pull both change
local state and need consent. Do not silently switch branches or discard edits.

Local overrides are ignored, not yet loaded. Keep SSH private keys, tokens,
history and personal/work-specific values out of the public repository. Each
machine gets its own SSH credentials. Ignore rules cannot detect secrets inside
otherwise legitimate configuration; review each file before publishing it.

## mise documentation checkpoint

The official documentation was checked on 2026-11-14:

- [Configuration](https://mise.jdx.dev/configuration.html) documents `[tools]`,
  `.config/mise/config.toml` and the adjacent `config.local.toml` override.
- [Dotfiles](https://mise.jdx.dev/dotfiles.html) documents native dotfile deployment
  and a preview with `mise dot apply --dry-run`.
- [Managed files](https://mise.jdx.dev/dotfiles/managed.html) describes symlink
  modes and conflict behaviour.

The only mise feature used now is an empty `[tools]` table. Before adopting native
deployment or package provisioning, choose and test a supported mise version,
verify its behaviour and ensure each modifying operation can be confirmed at the
required granularity. Native support is a candidate, not an implemented promise.
In particular, the documented symlink mode can repoint an existing different
symlink without `--force`. Future integration must preflight each target and
obtain an explicit decision for that conflict before invoking mise.
Do not run mise commands that install, trust or apply anything as scaffold checks.

## Validation boundary

`tests/run.sh` checks Bash syntax, representative OS fixtures, refusal of
noninteractive confirmation, entry-point help/error handling and read-only smoke
execution from another directory. Fixtures are temporary; no host OS metadata is
changed. Real macOS and Pop!_OS execution, interactive-terminal confirmation and
any future modifying operations also need validation before they are relied on.
