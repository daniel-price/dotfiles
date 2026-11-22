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
| Profiles | **Base + optional Profiles POC**: [activate, combine and deactivate](guides/profiles.md) selected Git repositories, with commands, aliases, app config, pinned tools and non-secret env values | Test an authorised Profile end to end; implement safe Profile updates and rollback before production use |
| Encrypted environment values | POC ready for manual validation | [**POC 1A:** age + mise, fake token and second-machine restore](guides/age-env-poc.md) |
| Encrypted files/history | POC ready for manual validation | [**POC 1B:** synthetic encrypted file, Git history inspection and restore](guides/age-file-poc.md) |
| Device identities (SSH/age) | Planned | New SSH identity and age recovery POC |
| Persistent services | Planned | Rootless container, network, restart, volume and backup POC |
| OS preferences | Planned | One reversible setting per platform |
| Backup and recovery | Planned | Rebuild from Git and independent encrypted backup |

Suggested sequence: **secrets → identities → config layering → services → OS/GUI settings → upgrades → disaster recovery**.

Each POC must answer one architectural question and include a manual test plan. Validate preview, approval/refusal, no-op rerun, conflicts, failure, recovery and platform differences as relevant. For encryption, also verify ciphertext-only Git history, missing-key failure and recovery on a fresh machine. Never use real credentials or work-owned repositories in experiments.

## Profiles roadmap

**Base** is the shared configuration in this repository. **Profiles** are reusable, explicitly selected Git repositories: for example, a personal laptop can use `personal`, a work Mac can use `personal` and an employer-approved `work` profile, and a home server can use `home-server`. Profile selection never blocks Base bootstrap. **Local** (per-device configuration) is not implemented and is deferred until a concrete need arises.

| Priority | Capability | Planned POC / acceptance criteria |
| --- | --- | --- |
| **Before production** | Profile lifecycle: update, deactivate, remove and rollback | **Deactivation in this PR:** previews, confirms, removes only verified owned symlinks, recomposes remaining profiles and preserves clones/installed tools. **Still needed:** safe authenticated fast-forward previews, refusal of dirty/diverged repos, explicit removal/rollback and recovery tests on real macOS and Pop!_OS machines. |
| **POC in this PR** | Literal non-secret environment variables | An optional `[env]` table in profile `mise.toml`, with string-only values, reserved-name checks and cross-profile conflict refusal. Effective variables are declared through the managed mise manifest; no arbitrary environment scripts or secrets in Git. |
| **Next** | PATH composition and environment precedence | Declarative extra search paths, order, portability and composition across Profiles; refuse unsafe paths and clashes. Local is out of scope. No automatic execution of profile snippets. |
| **Next** | Profile OS packages | Declare additional packages per OS (`apt` on Pop!_OS, Homebrew on macOS). Preview the exact package/OS operations, ask before each install/upgrade and prevent unreviewed removals; reuse existing declarative mise integration where suitable. |
| **Next** | Git identity and configuration | Per-profile Git user/email, signing preference, aliases and `includeIf` scoped to authorised directories or repositories. Avoid changing global identity for unrelated work; never store signing private keys in Git. |
| **Later** | GUI applications and settings | Optional per-platform apps (e.g. browser, Ghostty, VS Code), with tested installers, paths, permissions and explicit approval; treat app installation separately from file configuration. |
| **Later** | OS/device preferences | Keyboard, power, display and other reversible settings; preview OS-specific effects and provide a rollback path. |
| **Later** | Services and scheduled jobs | Home-server examples: Jellyfin, Radarr and backup timers. Test rootless services, permissions, restart policy, persistent volumes, health checks and recovery. |
| **Later** | Secrets references | Profiles name required secrets or encrypted files but **never** contain credentials or private keys in plaintext. Use independently secured identities, recovery and per-machine access controls. |
| **Deferred** | Local per-device configuration | Only add this concept when real device-only settings (hostnames, mount paths, monitor layouts) need management. Until then, leave them manually configured; if added, test Base → Profiles → Local precedence and rollback. |

Start with real-profile manual validation and safe Git update/rollback. Environment values and profile deactivation are part of the current POC; implement the remaining **Next** capabilities (PATH, OS packages and Git identity) as separate, narrowly scoped POCs. Add GUI, OS settings, services and secrets references only with their own security and rollback tests. Do not implement Local yet. Work-owned material must remain in employer-approved storage.

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
