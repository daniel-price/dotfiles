# Operating systems and machine-specific configuration

The supported baseline is **Pop!_OS / Debian-derived Linux** and **macOS**.
The machine inventory is declared in
[`scripts/setup/mise.toml`](../../scripts/setup/mise.toml). The
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
| Reviewed `~/.zshrc` | Native `mise dot apply`, offered early with separate approval | Same |

The initial bootstrap uses a small shell wrapper to install mise with a
verified installer and preserve independent confirmations for each missing
component. Once mise is present, the script selects the declarative machine
configuration using `MISE_GLOBAL_CONFIG_FILE` and invokes mise with
`-C /`: this **excludes checkout development tools**. It does not silently activate Zsh, trust private repositories or update
software. After mise and Zsh are available, bootstrap calls the separately
runnable reviewed Zsh deployment script, **before** Neovim and Zellij setup.
Deployment only proceeds after a preview and explicit confirmation. Bootstrap
skips conflicting existing `~/.zshrc` files/symlinks without preventing tool
installation. Native mise can repoint a foreign symlink, so its wrapper retains
the conflict-refusal checks.

## Selective cleanup

`bash scripts/setup/cleanup.sh` previews removal of the reviewed zsh symlink
and the exact declared Neovim/Zellij mise versions; `--apply` prompts for each.
It never removes system packages, mise, unrelated tool versions, private
overlays, or the checkout. Other projects may rely on the same mise version;
there is no installation-ownership ledger.

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

## Configuration boundaries

Public defaults are reviewed in this repository. Optional private overlays
must be chosen explicitly and never auto-discovered. Private keys and
work-specific settings belong outside the public repo. A future recurring
update command must guard dirty/diverged checkouts and ask before fetching
or modifying the machine.
