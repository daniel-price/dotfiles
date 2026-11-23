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
| Machine modules and profiles | **Native mise adoption in review**: [Base, optional modules, and private repositories](guides/profiles.md) | Validate on real machines; migrate legacy Profiles and then remove legacy code |
| Encrypted environment values | POC ready for manual validation | [**POC 1A:** age + mise, fake token and second-machine restore](guides/age-env-poc.md) |
| Encrypted files/history | POC ready for manual validation | [**POC 1B:** synthetic encrypted file, Git history inspection and restore](guides/age-file-poc.md) |
| Device identities (SSH/age) | Planned | New SSH identity and age recovery POC |
| Persistent services | Planned | Rootless container, network, restart, volume and backup POC |
| OS preferences | Planned | One reversible setting per platform |
| Backup and recovery | Planned | Rebuild from Git and independent encrypted backup |

Suggested sequence: **secrets → identities → config layering → services → OS/GUI settings → upgrades → disaster recovery**.

Each POC must answer one architectural question and include a manual test plan. Validate preview, approval/refusal, no-op rerun, conflicts, failure, recovery and platform differences as relevant. For encryption, also verify ciphertext-only Git history, missing-key failure and recovery on a fresh machine. Never use real credentials or work-owned repositories in experiments.

## Machine module migration

**Base** is the shared configuration in this repository. **Profiles** are reusable, explicitly selected Git repositories: for example, a personal laptop can use `personal`, a work Mac can use `personal` and an employer-approved `work` profile, and a home server can use `home-server`. Profile selection never blocks Base bootstrap. **Local** (per-device configuration) is not implemented and is deferred until a concrete need arises.

| Status | Capability | Scope / acceptance criteria |
| --- | --- | --- |
| **Implemented / migrate** | Native module selection, opt-in private Git repos and app setup | Test and adopt the native module guide; retire legacy `,profile` only after real-device validation. |
| **Native mise** | Environment variables and PATH | Use `[env]` and `_.path` inside selected modules, with approved private configuration. |
| **Native mise** | Private repository checkout and updates | Use `bootstrap.repos` with mise's origin and dirty-worktree safeguards. |
| **Native mise** | Selected OS packages | Per-module `bootstrap.packages`; preview/approve each module setup. |
| **Next** | Git identity and configuration | Per-profile Git user/email, signing preference, aliases and `includeIf` scoped to authorised directories or repositories. Avoid changing global identity for unrelated work; never store signing private keys in Git. |
| **Later** | GUI applications and settings | Optional per-platform apps (e.g. browser, Ghostty, VS Code), with tested installers, paths, permissions and explicit approval; treat app installation separately from file configuration. |
| **Later** | OS/device preferences | Keyboard, power, display and other reversible settings; preview OS-specific effects and provide a rollback path. |
| **Later** | Services and scheduled jobs | Home-server examples: Jellyfin, Radarr and backup timers. Test rootless services, permissions, restart policy, persistent volumes, health checks and recovery. |
| **Later** | Secrets references | Profiles name required secrets or encrypted files but **never** contain credentials or private keys in plaintext. Use independently secured identities, recovery and per-machine access controls. |
| **Deferred** | Local per-device configuration | Only add this concept when real device-only settings (hostnames, mount paths, monitor layouts) need management. Until then, leave them manually configured; if added, test Base → Profiles → Local precedence and rollback. |

Migrate real machines carefully, test approval/refusal and configuration conflicts, then remove the legacy profile composer. Add GUI, OS settings, services and secrets references only with independent security and rollback tests. Work-owned material must remain in employer-approved storage.

## Tools, apps and services

| Category | Examples | State |
| --- | --- | --- |
| Core setup | Git, mise, Zsh | Implemented |
| CLI tools | Neovim, Zellij, zoxide, ripgrep, fd | Implemented; versions in [machine manifest](../scripts/setup/mise.toml) |
| Shell config | Zsh aliases, bookmarks, Powerlevel10k and autosuggestions | Implemented; optional pinned plugins |
| Repo tooling | shfmt, ShellCheck, Lefthook | Implemented; opt-in hooks |
| On-demand isolated app | OpenCode through rootless Podman | Implemented on Linux; approval required |
| GUI apps/config | Ghostty and Neovim configs | Ghostty: declarative mise OS package (Pop!_OS 24.04 PPA/macOS cask); Neovim: independent LazyVim Git checkout and locked-plugin bootstrap |
| Long-running services | Jellyfin, Radarr (examples) | Not implemented |

Add a **capability POC** only for a new mechanism. Add an **application change** to its existing manifest/config once the mechanism is proven. Desktop apps, CLI tools, short-lived agents and persistent services need not share an installation strategy.

## Conventions

Keep each feature a small PR with a copyable manual test plan. Update statuses here when work lands. Public setup must never depend on private access, and changes must not silently overwrite files or upgrade packages.

[Detailed original plan (archive)](reference/scaffold-roadmap.md)
