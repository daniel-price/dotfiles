# Getting started

The one-command installer ensures Git, acquires the public repository and
**offers to run its bootstrap with a separate confirmation**. Bootstrap then
checks mise and Zsh, then offers the tools declared in the
[reviewed machine manifest](../../scripts/setup/mise.toml) with separate
confirmations for missing installations. An optional explicit overlay can deploy one selected private
configuration directory. The full development-environment setup remains
unimplemented.

## Fresh machine: one-file bootstrap

Prerequisites: Bash 3.2+ and curl; Git and GitHub SSH keys are **not** required.
Bash is included on standard macOS and Pop!_OS installations, but not every
minimal Linux image. Supported hosts are macOS and Debian/Ubuntu-derived Linux
(including Pop!_OS).

```sh
(
  tmp_dir=$(mktemp -d) || exit 1
  script="$tmp_dir/get-started.sh"
  trap 'rm -rf "$tmp_dir"' EXIT
  curl -fsSLo "$script" \
    https://raw.githubusercontent.com/daniel-price/dotfiles/main/get-started.sh &&
    bash "$script"
)
```

**Copy the whole code block above into a terminal.** It downloads only
`get-started.sh` into a temporary directory, executes it after the download
finishes, and **deletes the temporary directory automatically** on exit or
ordinary failure. No downloaded script remains in your current directory.
[Read the script on GitHub](https://github.com/daniel-price/dotfiles/blob/main/get-started.sh)
before running downloaded code.

The script checks Git, asking before installation if needed (apt on Linux or
Apple Command Line Tools on macOS). It asks separately before an HTTPS clone
into `~/.dotfiles`, then **asks a third time before running** the checkout's
`scripts/setup/bootstrap.sh`. It runs bootstrap from the repository directory without
changing your terminal's working directory.

On macOS, complete the Command Line Tools installer and rerun if Git was
missing. An existing matching checkout is reused without cloning again.
If it contains the reviewed updater, stage zero offers to fetch `origin/main`
then separately offers a safe switch/fast-forward if needed, **before**
choosing which bootstrap script to run. An old checkout without the updater
remains usable, with instructions to update it manually. Conflicting
destinations are never overwritten. Declining an update does not prevent
bootstrap from running on the existing code.

The checkout bootstrap installs verified mise first, then uses the
**machine-only** `scripts/setup/mise.toml` for `[bootstrap.packages]`,
`[tools]` and `[dotfiles]`. That config is selected explicitly; the root
`mise.toml` for Git hooks and development tools is not loaded during setup.
A missing zsh is installed by mise using apt on Debian-derived Linux or,
on macOS where zsh is usually already present, Homebrew if needed.
There is a separate approval before each missing component.

Curl is required for the initial standalone download and to fetch the mise
installer if mise is missing. If curl is absent, install it manually first.
This keeps system package management in mise, rather than maintaining a
second general-purpose apt/Homebrew installer in Bash.

Older checkouts with `scripts/bootstrap.sh` or the original root
`bootstrap.sh` are still supported. They are never silently updated;
checkouts missing `scripts/setup/update.sh` are left on their existing
revision and can be upgraded manually.

The [per-platform installed tool inventory](../architecture/platforms.md#installed-tool-inventory)
lists every tool this repository currently installs, its installer and its
scope. It also distinguishes optional checkout-development tooling from the
machine bootstrap.

For missing mise, bootstrap pins `v2026.11.9`. It asks first to download the
official release installer to a temporary file and verify its committed
SHA-256, then asks again before running it. The installer writes only
`~/.local/bin/mise` and may create its missing parent directories. It downloads
the release only from GitHub and verifies that release before installation. An
existing mise found on `PATH` or at that destination is reported and left
unchanged, even when it is an older version. Once mise and Zsh are available, bootstrap **offers** to deploy the reviewed
`~/.zshrc` via `scripts/setup/deploy-zsh-config.sh` before provisioning Neovim
and Zellij. It previews the symlink and requires its own confirmation. Existing
non-managed `~/.zshrc` files or symlinks are preserved and reported without
blocking remaining setup. Accepting activates mise in **new Zsh sessions**, not
in the currently running shell. A declined offer can be retried independently.
After provisioning tools, bootstrap also offers to change the account's default
login shell to Zsh through `chsh`. This is an independent yes/no decision:
bootstrap checks the registered system shell, current account and login shell,
leaves already-correct settings alone, and never changes root's shell.
The new login shell takes effect after logging out and back in; it does not
switch an existing Bash process.
Bootstrap asks individually before installing any missing tools from
the exact versions in `scripts/setup/mise.toml`. Add another pinned tool to
that manifest and it is discovered automatically; no setup script changes are
needed. It never silently upgrades tools.

After approving zoxide installation, open a new Zsh session (`exec zsh`)
and visit a directory with `cd` to teach zoxide its location. For example,
`cd ~/.dotfiles` then `z dot`. zoxide learns visited directories; installing it
alone does not populate its history. If you declined zoxide installation,
the reviewed Zsh startup skips its initialization.

To deploy a private Neovim configuration, explicitly select an already-present
source directory and target directory after reviewing
[private profiles](../guides/private-profiles.md). The overlay script previews
with mise, refuses conflicting targets and dirty or diverged sources, and never
discovers, clones, fetches or updates a repository for you.

**Do not use `curl ... | bash`.** It interferes with the interactive
confirmation flow and can execute a partially downloaded script. The
temporary-file command downloads everything first.

## Activate mise in zsh (optional)

Bootstrap offers the reviewed `~/.zshrc` before installing Neovim and Zellij.
If you declined, or resolved a conflicting existing configuration, you can
rerun the deployment independently. The script requires mise `2026.11.9` or
newer and will refuse older versions without modifying the destination:

```sh
bash ~/.dotfiles/scripts/setup/deploy-zsh-config.sh --help
bash ~/.dotfiles/scripts/setup/deploy-zsh-config.sh
```

Expected: mise shows a diff and a dry-run first, then the script asks once before
applying a symlink to `.config/zsh/zshrc`. The public source prepends `~/.local/bin` to `PATH` once, selects the machine-only mise manifest from
its own resolved source path (unless explicitly overridden), then activates
mise and initialises zoxide when installed. This defines the `z` function; it
does not copy a private shell config. If
`~/.zshrc` already exists as a real file or a symlink to somewhere else, the
script refuses and makes no change. Merge or back up your existing file
yourself, then rerun. A repeat run with the correct symlink exits without a
prompt.

Deploying the Zsh startup file alone does not change the default login shell.
The **main bootstrap** now separately offers to configure Zsh as the account's
login shell using `chsh`, if the user approves. Existing Bash sessions remain
Bash; after approval, log out of the desktop session and back in for new login
shells to use Zsh. A terminal configured to force Bash may still override the
account preference. To verify mise without switching shell, run:

```sh
"$HOME/.local/bin/mise" exec neovim@0.12.6 -- nvim --version
```

## Set up development hooks (optional)

If you want to develop the dotfiles repository, first trust the reviewed
**checkout-only** tool configuration and install the pinned developer tools:

```sh
bash ~/.dotfiles/scripts/dev/run-mise.sh trust ~/.dotfiles/mise.toml
bash ~/.dotfiles/scripts/dev/install-dev-tools.sh
```

The second command offers to install the pre-commit hook when run from a
terminal. It requires a separate yes/no approval, refuses existing conflicting
hooks, and does nothing to Git hooks in CI. It uses the installed mise binary
even if the current Bash shell has no mise on `PATH`. Git-hook execution uses
that same fallback.

## Inspect the checkout scaffold

After approving the clone, the script offers to run the bootstrap.
To inspect or rerun it later:

```sh
bash ~/.dotfiles/scripts/setup/bootstrap.sh --help
bash ~/.dotfiles/scripts/setup/bootstrap.sh
bash ~/.dotfiles/tests/run.sh
```

**Expected:** bootstrap identifies the OS, checks mise and Zsh, and then
checks the reviewed `~/.zshrc` **before** proposing declared machine-tool installations.
It previews and offers the Zsh symlink if the destination is free, skips an
already-correct link, and preserves any conflicting file or other symlink.
Each missing tool requires separate approval. After tools, bootstrap offers
a separate login-shell change when needed. The final message reports the
Zsh configuration status. Tests use temporary fixtures and finish with
`All bootstrap checks passed.`

Every bootstrap change already requires its own confirmation. Read the code and
documentation for the version you check out before running it on a live machine.

## New machine: intended future flow

1. Download the standalone `get-started.sh` to a temporary directory and
   run it interactively; the wrapper automatically cleans up.
2. Ensure Git only if missing, with explicit approval.
3. Clone the public repository once. On an existing checkout, optionally
   fetch/switch/fast-forward with separate approvals, then approve bootstrap
   (implemented in stage zero).
4. Bootstrap checks and, with separate approvals, installs missing `zsh` and
   `curl` (implemented).
5. Bootstrap can download, verify and install missing mise `v2026.11.9` after
   separate approval (implemented). It does not activate mise.
6. After mise and Zsh are available, offer to deploy the reviewed Zsh startup
   symlink with its own confirmation, while preserving conflicts (implemented).
7. Provision every pinned machine tool from declarative mise configuration,
   with separate approvals (implemented).
8. Offer to set Zsh as the user's default login shell with `chsh` after a
   separate confirmation; already configured accounts are skipped (implemented).
9. Explicitly deploy one reviewed private configuration directory through the
   mise overlay (narrow prototype implemented).
10. Provision further reviewed tools and apply further reviewed dotfiles.
11. Restore authorised encrypted settings using a **separately recovered** age
    identity; keep machine-specific SSH credentials local.
12. Re-run without unnecessary changes; upgrades remain an explicit action.

**Not implemented:** SSH registration, further tool provisioning, broad dotfile
deployment, full private profiles and encrypted restore. Git installation, the
initial clone, a confirmed bootstrap handoff, individually approved
zsh package installation, verified mise installation, Neovim and Zellij
provisioning, the reviewed zsh activation file and the narrow overlay are
implemented.
No private repositories should be discovered or cloned automatically;
see [the private-profile guide](../guides/private-profiles.md).

## Preview and clean up managed items

The machine setup is intentionally **not** a fully reversible installer.
Removing a tool declaration does **not** automatically remove its previous
installation: only tools still declared by the reviewed manifest are eligible
for the selective cleanup below. The manifest is the source of truth for the
current tool inventory, not an ownership ledger.
You can preview removing items managed by the public mise manifest without
modifying your laptop:

```sh
bash ~/.dotfiles/scripts/setup/cleanup.sh
```

To select removals interactively:

```sh
bash ~/.dotfiles/scripts/setup/cleanup.sh --apply
```

Every eligible removal requires an explicit **yes** from a terminal; the default
answer is no and piped answers are rejected. The script delegates to
`mise dot unapply` and `mise uninstall`, showing their native dry runs first.
Only the following are eligible:

- The reviewed `~/.zshrc` symlink, **if it still points to this checkout's
  reviewed source**. Ordinary files or symlinks to another source are left alone.
- Only the exact tool versions currently declared in
  `scripts/setup/mise.toml`. These mise installations may be shared by other
  projects, and this script **cannot establish whether they existed before
  bootstrap**. Review that warning before approving a removal.

**Never removed:** apt/Homebrew zsh or other system packages; Git and curl;
mise and its unrelated installations; the public checkout; private-profile
sources or linked directories; credentials or other settings.

No installation-state journal is maintained. This is selective cleanup,
**not an exact restore of the pre-bootstrap machine state**. There is no
`--all`, `--force`, `mise implode` or package-manager prune operation.
It is safe to run from outside the checkout, but uses its reviewed manifest.

## Update an existing machine checkout safely

You can review the checkout without network access or mutations:

```sh
bash ~/.dotfiles/scripts/setup/update.sh
```

To offer to fetch `origin/main` and then switch to `main` or fast-forward:

```sh
bash ~/.dotfiles/scripts/setup/update.sh --apply
```

Every network fetch requires terminal approval. Branch switching and
fast-forwarding require a second approval, and only work in a clean checkout
with the expected GitHub origin and a local `main` that is not ahead or
diverged from `origin/main`. A missing local `main` can be created from the
fetched remote with its own confirmation. A dirty or detached checkout is
never modified, and a failed fetch (including offline operation) leaves the
checkout usable. The updater never resets, force-checks out, auto-stashes or
merges divergent history. The default status may compare against a **cached**
remote ref, which can be stale until you approve a fetch.

The standalone `get-started.sh` offers this update when it encounters an
existing compatible checkout with an updater, and then asks separately before
executing the resulting bootstrap script. A direct
`bash scripts/setup/bootstrap.sh` invocation does not update Git; it warns
if you are on a branch other than `main`.

A scheduled or unattended recurring update mechanism is still out of scope.

## Documentation preview

From a repository checkout:

```sh
python3 -m pip install zensical
zensical serve
```

This serves the Markdown documentation locally. It does **not** initialise the
development environment. See [the roadmap](../roadmap.md) for upcoming work.
