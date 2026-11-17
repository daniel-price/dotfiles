# Getting started

The one-command installer ensures Git, acquires the public repository and
**offers to run its bootstrap with a separate confirmation**. Bootstrap then
checks `zsh`, `curl`, mise, Neovim and Zellij, asking separately before each
missing installation. An optional explicit overlay can deploy one selected private
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
missing. An existing matching checkout is reused without fetching or
updating it. Existing conflicting destinations are never overwritten.
Declining any prompt skips that operation.

The checkout bootstrap installs verified mise first, then uses the
**machine-only** `.config/mise/config.toml` for `[bootstrap.packages]`,
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
`bootstrap.sh` are still supported by the standalone entry point, which
never updates an existing checkout automatically.

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
unchanged, even when it is an older version. Bootstrap then asks individually before installing the pinned Neovim and
Zellij versions declared in `.config/mise/config.toml`. It uses mise's
installed-state checks and never upgrades working installations silently.
The reviewed zsh startup file is declared in the same config but is **not
automatically deployed by bootstrap**: use the separate step below.

To deploy a private Neovim configuration, explicitly select an already-present
source directory and target directory after reviewing
[private profiles](../guides/private-profiles.md). The overlay script previews
with mise, refuses conflicting targets and dirty or diverged sources, and never
discovers, clones, fetches or updates a repository for you.

**Do not use `curl ... | bash`.** It interferes with the interactive
confirmation flow and can execute a partially downloaded script. The
temporary-file command downloads everything first.

## Activate mise in zsh (optional)

After bootstrap, install a reviewed `~/.zshrc` that activates mise so tools such
as `nvim` are available in new interactive zsh sessions. This requires mise
`2026.11.9` or newer; bootstrap installs that version. Older releases fail with
an explicit version message before any change:

```sh
bash ~/.dotfiles/scripts/setup/deploy-zsh-config.sh --help
bash ~/.dotfiles/scripts/setup/deploy-zsh-config.sh
```

Expected: mise shows a diff and a dry-run first, then the script asks once before
applying a symlink to `.config/zsh/zshrc`. The public source only activates mise
from `PATH` or `~/.local/bin/mise`; it does not copy a private shell config. If
`~/.zshrc` already exists as a real file or a symlink to somewhere else, the
script refuses and makes no change. Merge or back up your existing file
yourself, then rerun. A repeat run with the correct symlink exits without a
prompt.

This step does not change your current shell or a Bash session. Start a new zsh
session, or run `exec zsh`, to use the activated tools. To verify without
changing a shell, run:

```sh
"$HOME/.local/bin/mise" exec neovim@0.12.6 -- nvim --version
```

## Inspect the checkout scaffold

After approving the clone, the script offers to run the bootstrap.
To inspect or rerun it later:

```sh
bash ~/.dotfiles/scripts/setup/bootstrap.sh --help
bash ~/.dotfiles/scripts/setup/bootstrap.sh
bash ~/.dotfiles/tests/run.sh
```

**Expected:** bootstrap identifies the OS, skips available mise and zsh,
Neovim and Zellij, or asks separately before installing a missing component. Mise
requires separate download/verification and execution confirmation; Neovim and
Zellij each have their own install prompt. It then lists the unimplemented steps. The tests use temporary fixtures and should finish
with `All bootstrap checks passed.`

Every bootstrap change already requires its own confirmation. Read the code and
documentation for the version you check out before running it on a live machine.

## New machine: intended future flow

1. Download the standalone `get-started.sh` to a temporary directory and
   run it interactively; the wrapper automatically cleans up.
2. Ensure Git only if missing, with explicit approval.
3. Clone the public repository once and separately approve its bootstrap
   (implemented in stage zero).
4. Bootstrap checks and, with separate approvals, installs missing `zsh` and
   `curl` (implemented).
5. Bootstrap can download, verify and install missing mise `v2026.11.9` after
   separate approval (implemented). It does not activate mise.
6. Bootstrap can provision pinned Neovim and Zellij from its declarative config after separate
   approvals (implemented).
7. Optionally deploy the reviewed zsh startup file that activates mise
   (implemented).
8. Explicitly deploy one reviewed private configuration directory through the
   mise overlay (narrow prototype implemented).
9. Provision further reviewed tools and apply further reviewed dotfiles.
10. Restore authorised encrypted settings using a **separately recovered** age
   identity; keep machine-specific SSH credentials local.
11. Re-run without unnecessary changes; upgrades remain an explicit action.

**Not implemented:** SSH registration, further tool provisioning, broad dotfile
deployment, full private profiles and encrypted restore. Git installation, the
initial clone, a confirmed bootstrap handoff, individually approved
zsh package installation, verified mise installation, Neovim and Zellij
provisioning, the reviewed zsh activation file and the narrow overlay are
implemented.
No private repositories should be discovered or cloned automatically;
see [the private-profile guide](../guides/private-profiles.md).

## Existing machine: intended future flow

A recurring update command has not been implemented. A future one should check
the remote, guard dirty/diverged state, fast-forward only after approval and
preview each configuration change before applying it.

## Documentation preview

From a repository checkout:

```sh
python3 -m pip install zensical
zensical serve
```

This serves the Markdown documentation locally. It does **not** initialise the
development environment. See [the roadmap](../roadmap.md) for upcoming work.
