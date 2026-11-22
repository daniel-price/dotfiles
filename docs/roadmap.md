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
| Private configuration layers | Single directory overlay implemented; [real opt-in profile-repository POC](guides/private-profiles-poc.md) supports clone, app symlinks, shell functions/aliases, pinned tools and separate install consent | Manual end-to-end test with authorised private fixture; implement safe update/deactivation and rollback before production rollout |
| Encrypted environment values | POC ready for manual validation | [**POC 1A:** age + mise, fake token and second-machine restore](guides/age-env-poc.md) |
| Encrypted files/history | POC ready for manual validation | [**POC 1B:** synthetic encrypted file, Git history inspection and restore](guides/age-file-poc.md) |
| Machine-local identities | Planned | New SSH identity and age recovery POC |
| Persistent services | Planned | Rootless container, network, restart, volume and backup POC |
| OS preferences | Planned | One reversible setting per platform |
| Backup and recovery | Planned | Rebuild from Git and independent encrypted backup |

Suggested sequence: **secrets → identities → config layering → services → OS/GUI settings → upgrades → disaster recovery**.

Each POC must answer one architectural question and include a manual test plan. Validate preview, approval/refusal, no-op rerun, conflicts, failure, recovery and platform differences as relevant. For encryption, also verify ciphertext-only Git history, missing-key failure and recovery on a fresh machine. Never use real credentials or work-owned repositories in experiments.

## Machine-specific profile roadmap

Keep **profiles** (reusable sets of settings) separate from **machines** (individual hosts). For example, a personal laptop can activate `personal`; a work Mac might activate `personal` plus an employer-approved `work` profile; a home server might activate `personal` plus `home-server`. An individual host can additionally have local overrides that do not belong in any shared Git repository. Profile selection must remain explicit, and the public bootstrap must work without private access.

| Priority | Capability | Planned POC / acceptance criteria |
| --- | --- | --- |
| **Before production** | Profile lifecycle: update, deactivate, remove and rollback | Preview Git changes and effective configuration before explicit, authenticated fast-forward; refuse dirty/diverged repositories, foreign paths and changed trust boundaries. Deactivate one selected profile without affecting others, safely remove only owned symlinks/managed settings, show tool-dependency impact and restore after failure; test reruns on macOS and Pop!_OS. |
| **Next** | Profile environment variables and PATH | Declarative, non-secret variables such as `EDITOR`, `JAVA_HOME` and extra search paths; validate names, order/precedence, conflicts and shell quoting. Never source arbitrary environment snippets just to set values; no secrets in Git. |
| **Next** | Profile OS packages | Declare additional packages per OS (`apt` on Pop!_OS, Homebrew on macOS). Preview the exact package/OS operations, ask before each install/upgrade and prevent unreviewed removals; reuse existing declarative mise integration where suitable. |
| **Next** | Git identity and configuration | Per-profile Git user/email, signing preference, aliases and `includeIf` scoped to authorised directories or repositories. Avoid changing global identity for unrelated work; never store signing private keys in Git. |
| **Later** | GUI applications and settings | Optional per-platform apps (e.g. browser, Ghostty, VS Code), with tested installers, paths, permissions and explicit approval; treat app installation separately from file configuration. |
| **Later** | OS/device preferences | Keyboard, power, display and other reversible settings; preview OS-specific effects and provide a rollback path. |
| **Later** | Services and scheduled jobs | Home-server examples: Jellyfin, Radarr and backup timers. Test rootless services, permissions, restart policy, persistent volumes, health checks and recovery. |
| **Later** | Secrets references | Profiles name required secrets or encrypted files but **never** contain credentials or private keys in plaintext. Use independently secured identities, recovery and per-machine access controls. |
| **Later** | Host-local overrides | Hostnames, mount/disk paths, monitor layouts and device-specific values stored outside shared profile Git. Define and test explicit public → profile(s) → local precedence, validation and conflicts. |

Start with real-profile manual validation and lifecycle safety. Implement the three **Next** capabilities as separate, narrowly scoped POCs rather than expanding the current integration PR. Add GUI, OS settings, services, secrets references and host-local overrides only with their own security and rollback tests. Work-owned material must remain in employer-approved storage.

## Tools, apps and services

| Category | Examples | State |
| --- | --- | --- |
| Core setup | Git, mise, Zsh | Implemented |
| CLI tools | Neovim, Zellij, zoxide, ripgrep, fd | Implemented; versions in [machine manifest](../scripts/setup/mise.toml) |
| Shell config | Zsh aliases, bookmarks, Powerlevel10k and autosuggestions | Implemented; optional pinned plugins |
| Repo tooling | shfmt, ShellCheck, Lefthook | Implemented; opt-in hooks |
| On-demand isolated app | OpenCode through rootless Podman | Implemented on Linux; approval required |
| GUI apps/config | Ghostty and Neovim configs | Incremental migration; not a generic GUI installer |
| Long-running services | Jellyfin, Radarr (examples) | Not implemented |

Add a **capability POC** only for a new mechanism. Add an **application change** to its existing manifest/config once the mechanism is proven. Desktop apps, CLI tools, short-lived agents and persistent services need not share an installation strategy.

## Conventions

Keep each feature a small PR with a copyable manual test plan. Update statuses here when work lands. Public setup must never depend on private access, and changes must not silently overwrite files or upgrade packages.

[Detailed original plan (archive)](reference/scaffold-roadmap.md)
