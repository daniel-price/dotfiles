# Operating systems and machine-specific configuration

The supported baseline is **Pop!_OS / Debian-derived Linux** and **macOS**.
The machine inventory is declared in
[`scripts/setup/mise.toml`](../../scripts/setup/mise.toml). The
root `mise.toml` describes checkout development only.

## Installed tool inventory

The authoritative current list of machine tool names and versions is the
[`[tools]` section of the reviewed machine manifest](../../scripts/setup/mise.toml).
Bootstrap and cleanup enumerate that section using mise; this document does not
maintain a second list or require edits when adding or removing a tool.


| Component | Pop!_OS / Ubuntu | macOS |
| --- | --- | --- |
| Git, only if missing at stage zero | `apt-get install git` after approval | Apple Command Line Tools dialog |
| curl, stage-zero prerequisite | Must already be available | Built into standard macOS |
| mise `2026.11.9` | Verified pinned GitHub installer, opt-in | Same installer, opt-in |
| zsh, when missing | `apt:zsh` via `mise bootstrap --only packages` | `brew:zsh` via mise if macOS's built-in zsh is missing and Homebrew exists |
| Machine CLI tools from [`[tools]`](../../scripts/setup/mise.toml) | Each exact pinned version offered individually through mise | Same |
| Reviewed `~/.zshrc` | Native `mise dot apply`, offered early with separate approval | Same |
| Default Zsh login shell | `chsh -s` with separate confirmation, account and `/etc/shells` checks | Same; account read through `dscl` |

The initial bootstrap uses a small shell wrapper to install mise with a
verified installer and preserve independent confirmations for each missing
component. Once mise is present, the script selects the declarative machine
configuration using `MISE_GLOBAL_CONFIG_FILE` and invokes mise with
`-C /`: this **excludes checkout development tools**. It does not silently activate Zsh, trust private repositories or update
software. After mise and Zsh are available, bootstrap calls the separately
runnable reviewed Zsh deployment script, **before** iterating over the declared machine tools.
Deployment only proceeds after a preview and explicit confirmation. Bootstrap
skips conflicting existing `~/.zshrc` files/symlinks without preventing tool
installation. Native mise can repoint a foreign symlink, so its wrapper retains
the conflict-refusal checks.

## Manifest-driven tool management

`scripts/lib/machine-tools.sh` uses `mise ls --current` to enumerate the
machine-only configuration, then `mise config get --file` to read each literal
pinned version from the reviewed manifest. Bash does not parse TOML or list
specific tools. Only exact numeric version pins are accepted; floating ranges,
aliases, undeclared tools and external overrides cannot become install or
cleanup targets. Bootstrap previews installed status and asks before each
missing installation; cleanup previews exactly pinned versions and asks
before each removal. Neither process infers who originally installed a version.
Removing a tool from the manifest means it is no longer eligible for
manifest-driven cleanup; previously installed versions are not tracked.

## Shell integration

The reviewed Zsh source resolves its own symlink target to locate the machine
manifest, setting `MISE_GLOBAL_CONFIG_FILE` unless the user already set a
different value. That makes pinned machine tools visible in new Zsh sessions,
even outside this checkout. After mise activation, it runs `zoxide init zsh`
only when zoxide is available; this defines the `z` shell function.
Missing zoxide does not break shell startup. The machine manifest remains
separate from the root `mise.toml` for checkout development.

## Default login shell

Bootstrap checks the current user's configured login shell independently of
`$SHELL` or the current Bash process. When Zsh is installed, executable and
registered in `/etc/shells`, it offers `chsh -s` **once, after tool setup**,
with a separate interactive confirmation. The target is restricted to an
executable registered Zsh, the account home must match the current HOME,
and the root account is never modified. An already-correct login shell is left
alone. The change affects subsequent login sessions, not an existing Bash
process; terminal-specific shell overrides may take precedence.

## Selective cleanup

`bash scripts/setup/cleanup.sh` previews removal of the reviewed zsh symlink
and the exact versions declared in the machine manifest; `--apply` prompts for each.
It never removes system packages, mise, unrelated tool versions, private
overlays, or the checkout. Other projects may rely on the same mise version;
there is no installation-ownership ledger.

## Sandboxed coding agent (Pop!_OS only)

OpenCode is deliberately **not** in the host mise machine-tool manifest. The
reviewed `bin/opencode-sandbox` launcher uses rootless Podman and only the
selected personal Git checkout as a writable mount. Podman is declared in a separate optional mise manifest and offered
via apt only when a workload needs it; the main bootstrap and cleanup do
not install or remove Podman or its images. A default read-only preview and separate
prompts for pull/build/run prevent unattended provisioning. This container
launcher is Linux-only; no macOS runtime is claimed. A separate
[optional shared Podman setup](../guides/podman.md) offers the declared
`apt:podman` package on demand after preview and explicit approval;
future workloads can reuse it. See the
[OpenCode sandbox guide](../guides/opencode.md).

## Checkout development tools

The checkout setup script installs pinned developer tools from the root
`mise.toml` and offers to enable a local Git hook only from an interactive
terminal, after a separate approval. Formatting, linting and the hook command
use `scripts/dev/run-mise.sh` to resolve mise on `PATH` or at
`~/.local/bin/mise`. They do not depend on the currently running shell.


The root `mise.toml` pins Lefthook `2.2.2`, shfmt `3.14.1`
and ShellCheck `0.11.0`. Only `bash scripts/dev/install-dev-tools.sh`
installs those versions for contributing or CI. Documentation builds use
Python and Zensical separately; neither belongs in machine bootstrap.

## Git update boundary

`scripts/setup/update.sh` (local status by default, `--apply` for
interactive fetch and optional switch/fast-forward) only operates on the
explicitly validated personal checkout. The bootstrap never updates its own
source mid-execution. The standalone `get-started.sh` checks for the updater
in an existing checkout before launching bootstrap. A new clone needs no
update. Dirty, detached or diverged checkouts and unexpected origins are left
alone; a remote fetch failure permits offline bootstrap.

## Configuration boundaries

Public defaults are reviewed in this repository. Optional private overlays
must be chosen explicitly and never auto-discovered. Private keys and
work-specific settings belong outside the public repo. An unattended recurring
update command is still out of scope; any future mechanism must preserve
the existing guards on fetches, dirty/diverged checkouts and machine changes.
