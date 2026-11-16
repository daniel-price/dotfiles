# Operating systems and machine-specific configuration

The shared baseline covers **Pop!_OS** and **macOS**. Differences should be
explicit instead of hidden inside a monolithic installation script.

| Concern | Pop!_OS | macOS |
| --- | --- | --- |
| OS detection | Debian/Ubuntu family, including `ID_LIKE` | Darwin |
| System packages | apt | Homebrew |
| Runtime and dotfile declarations | mise installed on approval; declarations planned | mise installed on approval; declarations planned |
| Interactive shell | zsh installed on approval; configuration planned | zsh installed on approval; configuration planned |
| Bootstrap language | Bash | System Bash 3.2-compatible |

A missing package must be checked and approved before installation. An
existing tool should not be upgraded merely because an update script ran.

## Installed tool inventory

This is the complete list of software the public scripts currently install.
Every bootstrap operation first checks its current state and asks interactively;
the commands below are the commands it runs after approval. `sudo` is omitted
when bootstrap is already running as root.

| Tool | Debian/Ubuntu/Pop!_OS | macOS | Scope |
| --- | --- | --- | --- |
| Git | `sudo apt-get install git` | `xcode-select --install` installs Apple Command Line Tools, including Git | Standalone `get-started.sh`; only if Git is missing |
| zsh | `sudo apt-get install --no-upgrade zsh` | `HOMEBREW_NO_AUTO_UPDATE=1 brew install zsh` | Checkout bootstrap; only if zsh is missing |
| curl | `sudo apt-get install --no-upgrade curl` | `HOMEBREW_NO_AUTO_UPDATE=1 brew install curl` | Checkout bootstrap; only if curl is missing |
| mise `v2026.11.9` | Verified GitHub Release installer writes `~/.local/bin/mise` | Same verified GitHub Release installer and destination | Checkout bootstrap; only if mise is missing |
| Neovim `0.12.6` | `mise install neovim@0.12.6` through `scripts/provision-tool.sh` | Same mise command on both operating systems | Checkout bootstrap; only if this version is not already installed |

The macOS zsh/curl path requires an existing Homebrew installation; bootstrap
does **not** install Homebrew. Standard macOS installations normally already
include both tools. The mise flow downloads the pinned official GitHub Release
installer to a temporary file, verifies its committed SHA-256, then asks again
before it writes the executable. It does not use apt or Homebrew, activate mise
or edit shell startup files. The only managed tool currently provisioned is
Neovim, installed through mise after its own confirmation. See
[Getting started](../getting-started/index.md) for the full consent and conflict
behaviour.

Apart from the Apple Command Line Tools bundle requested only to obtain missing
Git on macOS, bootstrap installs no other system package, application, shell
setting or dotfile.

## Checkout Development Tools

The following tools are installed only when a checkout developer deliberately
runs `bash scripts/install-dev-tools.sh`. That script runs `mise install`, so
the installer is the same on both supported operating systems and uses the
versions in the root `mise.toml`; bootstrap does not install these tools.

| Tool | Version | Installer on Pop!_OS/Ubuntu and macOS | Scope |
| --- | --- | --- | --- |
| Lefthook | `2.2.2` | `mise install` through `bash scripts/install-dev-tools.sh` | Optional Git hooks for this checkout |
| shfmt | `3.14.1` | `mise install` through `bash scripts/install-dev-tools.sh` | Format tracked Bash scripts |
| ShellCheck | `0.11.0` | `mise install` through `bash scripts/install-dev-tools.sh` | Lint tracked Bash scripts |
| Zensical | Resolved by pip; not pinned yet | `python3 -m pip install zensical` through `bash scripts/install-docs-deps.sh` in an activated virtual environment | Build the documentation site |

Python itself is a prerequisite for the Zensical workflow, not installed by
this repository. See [Develop this repository](../guides/development.md) for
the explicit developer and documentation setup commands.

## Where differences belong

- **Shared public settings:** versioned config and templates in this repo,
  eventually deployed by mise.
- **Platform variants:** explicit, versioned platform-specific config **when
  introduced**; there is not yet an implemented per-platform directory.
- **Private profiles:** an optional, separately authorised Git repository may
  supply non-public personal/work settings on deliberately selected machines.
  The current implementation deploys only one explicitly selected directory to
  one target; full profiles are not implemented.
- **Machine-local overrides:** identities, keys and host-only settings remain
  outside Git; `local/` and `*.local` are ignored but not yet loaded.
- **Sensitive identities:** outside the public Git checkout, with secure
  recovery and explicit access decisions.

The intended precedence is public defaults, approved private overlay and
local-only overrides last, with collisions explicitly reviewed. Mise config
load order must be verified rather than assumed; see
[configuration layers](private-configuration.md).

Avoid embedding hostnames, personal addresses, work settings or actual SSH
private keys in public documentation.
