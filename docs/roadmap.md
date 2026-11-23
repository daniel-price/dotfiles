# Roadmap

Two tracks: **capabilities** prove reusable mechanisms; **tools/apps** adopt them. POCs use synthetic data and isolated environments. See [architecture](architecture/index.md) for design choices and [history](reference/index.md) for older detailed plans.

## Capabilities and POCs

| Capability | Status | Next step |
| --- | --- | --- |
| Initial bootstrap (mise, prerequisites; Git required before clone) | Implemented | Extend only as needed |
| Pinned CLI tools and OS packages | Implemented | GUI application packaging POC |
| Dotfile deployment | Zsh and Zellij implemented with mise | Add reviewed configs as needed |
| Optional pinned Git dependencies | Powerlevel10k and zsh-autosuggestions implemented | Reuse as needed |
| Guarded Git update and selective cleanup | Implemented | Explicit upgrades, drift and rollback |
| Machine modules | Base config and sandbox-only OpenCode module configured through native mise; [guide](guides/mise-modules.md). | Test module selection on Pop!_OS/macOS, private-repo setup and deselection |
| Encrypted environment values | POC ready for manual validation | [**POC 1A:** age + mise, fake token and second-machine restore](guides/age-env-poc.md) |
| Encrypted files/history | POC ready for manual validation | [**POC 1B:** synthetic encrypted file, Git history inspection and restore](guides/age-file-poc.md) |
| Device identities (SSH/age) | Planned | New SSH identity and age recovery POC |
| Persistent services | Planned | Rootless container, network, restart, volume and backup POC |
| OS preferences | Planned | One reversible setting per platform |
| Backup and recovery | Planned | Rebuild from Git and independent encrypted backup |

Suggested sequence: **secrets → identities → config layering → services → OS/GUI settings → upgrades → disaster recovery**.

Each POC must answer one architectural question and include a manual test plan. Validate preview, approval/refusal, no-op rerun, conflicts, failure, recovery and platform differences as relevant. For encryption, also verify ciphertext-only Git history, missing-key failure and recovery on a fresh machine. Never use real credentials or work-owned repositories in experiments.

## Machine modules roadmap

Use native mise configuration environments to select tools and services per
machine. Keep public optional modules in `dotfiles`, and use local, explicitly
authorised `[bootstrap.repos]` declarations for private sources.

| Priority | Capability | Next step |
| --- | --- | --- |
| Next | Native module validation | Test Base, work, personal and home-server combinations, opt-in PATH and refusal |
| Next | Private repositories | Test safe checkout, local module loading and idempotent updates with synthetic Git fixtures |
| Next | Module removal | Preview deselection, installed-tool retention and explicit resource cleanup |
| Later | Service lifecycle | Prototype rootless Radarr containers, volumes, backups and scheduled jobs |
| Later | OS and device preferences | Add reversible host settings only when needed |

## Tools, apps and services

| Category | Examples | State |
| --- | --- | --- |
| Core setup | Git, mise, Zsh | Implemented |
| CLI tools | Neovim, Zellij, zoxide, ripgrep, fd | Implemented; versions in [machine manifest](../setup/mise.toml) |
| Shell config | Zsh aliases, bookmarks, Powerlevel10k and autosuggestions | Implemented; optional pinned plugins |
| Repo tooling | shfmt, ShellCheck, Lefthook | Implemented; opt-in hooks |
| On-demand isolated app | OpenCode through rootless Podman | Implemented on Linux; approval required |
| GUI apps/config | Ghostty and Neovim configs | Ghostty: declarative mise OS package (Pop!_OS 24.04 PPA/macOS cask); Neovim: independent LazyVim Git checkout and locked-plugin bootstrap |
| Long-running services | Jellyfin, Radarr (examples) | Not implemented |

Add a **capability POC** only for a new mechanism. Add an **application change** to its existing manifest/config once the mechanism is proven. Desktop apps, CLI tools, short-lived agents and persistent services need not share an installation strategy.

## Conventions

Keep each feature a small PR with a copyable manual test plan. Update statuses here when work lands. Public setup must never depend on private access, and changes must not silently overwrite files or upgrade packages.

[Detailed original plan (archive)](reference/scaffold-roadmap.md)
