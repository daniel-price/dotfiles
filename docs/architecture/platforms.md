# Operating systems and machine-specific configuration

The supported baseline is **Pop!_OS / Debian-derived Linux** and **macOS**.
The machine inventory is declared in
[`.config/mise/config.toml`](../../.config/mise/config.toml). The
root `mise.toml` describes checkout development only.

## Installed tool inventory

| Component | Pop!_OS / Ubuntu | macOS |
| --- | --- | --- |
| Git, only if missing at stage zero | `apt-get install git` after approval | Apple Command Line Tools dialog |
| curl, stage-zero prerequisite | Must already be available | Built into standard macOS |
| mise `2026.11.9` | Verified pinned GitHub installer, opt-in | Same installer, opt-in |
| zsh, when missing | `apt:zsh` via `mise bootstrap --only packages` | `brew:zsh` via mise if macOS's built-in zsh is missing and Homebrew exists |
| Neovim `0.12.6` | `mise install neovim`, opt-in | Same |
| Zellij `0.46.0` | `mise install zellij`, opt-in | Same |
| Reviewed `~/.zshrc` | Native `mise dot apply`, separate approval | Same |

The initial bootstrap uses a small shell wrapper to install mise with a
verified installer and preserve independent confirmations for each missing
component. Once mise is present, the script selects the declarative machine
configuration using `MISE_GLOBAL_CONFIG_FILE` and invokes mise with
`-C /`: this **excludes checkout development tools**. It does not silently
activate zsh, link dotfiles, trust private repositories or update software.

The `~/.zshrc` deployment is deliberately a separate command that checks
for existing files and foreign symlinks before calling native mise dotfiles.
Native mise can repoint a wrong symlink; the wrapper must continue to refuse it.

## Checkout development tools

The root `mise.toml` pins Lefthook `2.2.2`, shfmt `3.14.1`
and ShellCheck `0.11.0`. Only `bash scripts/dev/install-dev-tools.sh`
installs those versions for contributing or CI. Documentation builds use
Python and Zensical separately; neither belongs in machine bootstrap.

## Configuration boundaries

Public defaults are reviewed in this repository. Optional private overlays
must be chosen explicitly and never auto-discovered. Private keys and
work-specific settings belong outside the public repo. A future recurring
update command must guard dirty/diverged checkouts and ask before fetching
or modifying the machine.
