# Roadmap

Track **reusable machine-management capabilities** separately from the **specific
tools, apps and services** that use them. A POC proves a mechanism using synthetic
fixtures; adding another application is an adoption task, not a new capability.
This page is the maintained high-level plan. See [architecture](architecture/index.md),
[requirements](requirements.md) and [historical reference](reference/index.md)
for design rationale and detailed earlier acceptance criteria.

## Status at a glance

The public stage-zero installer, consent-gated mise bootstrap, pinned CLI tools,
reviewed Zsh dotfile, optional Powerlevel10k Git checkout, guarded Git update,
selective cleanup, narrow private-directory overlay and rootless OpenCode
launcher are implemented. Full private profiles, secret restoration, managed
persistent services and broader OS settings are not.

"Implemented" means the mechanism exists in the repo, **not** that it has
been applied or verified on every device. "POC" is deliberately limited and
does not imply production-ready secret storage or unattended operation.

## Track A — Capabilities and POCs

Each row represents a **different kind of thing the system must be able to
manage**, independent of a particular program. Keep a POC small, reviewable and
safe to run against a disposable HOME or synthetic data.

| Capability | Proven/current implementation | Next POC or gap | State |
| --- | --- | --- | --- |
| **Bootstrap and prerequisite acquisition** | Self-contained stage zero, approved Git installation/HTTPS clone, verified pinned mise installation, reviewed handoff | Complete remaining machine setup only through the other capabilities below | Implemented baseline |
| **Declarative CLI tools and OS packages** | Native mise manifest; exact pinned tools and Zsh package, with individual approvals and installed-state checks | Prove a distinct GUI app/package path (apt/Flatpak on Linux, appropriate macOS packaging) without conflating it with a mise CLI runtime | CLI/package baseline implemented; GUI POC planned |
| **Managed configuration files** | Native mise dotfiles, reviewed Zsh symlink and conflict refusal | Migrate another small real config; prove a whole directory, diff, rollback and non-overlapping ownership where needed | Single-file POC implemented; expansion planned |
| **Optional external Git dependencies** | Pinned Powerlevel10k theme, separately approved with native mise repos | Reuse pattern only when a future dependency genuinely needs a Git checkout | Implemented |
| **Git updates, drift and lifecycle** | Read-only status, guarded fetch/fast-forward, preview-first selective cleanup | Dedicated tool **upgrade** and rollback flow; report configuration drift without silently repairing it | Update/cleanup implemented; upgrades planned |
| **Non-secret private profiles and precedence** | Explicit one-target, no-clone private directory overlay | Compose public + explicitly selected synthetic private + machine-local settings; verify effective mise precedence, overlaps, refusal and removal | Narrow POC implemented; full composition planned |
| **Encrypted environment values** | Nothing enabled | **POC 1A:** age-encrypt a fake token using the pinned mise version; test first encryption, missing identity, second-machine restore and no plaintext in public source/logs | Planned — next |
| **Encrypted whole files and history** | Nothing enabled | **POC 1B:** `mise dot track --encrypt` with a fake credential file; inspect the first Git history commit, test restoration and keep its distinct history origin separate from this public repo | Planned |
| **Machine-local identity and authentication** | Policy: SSH private keys and age identities stay outside Git | Generate a new per-machine SSH key, document public-key registration/verification, and test secure age identity recovery without publishing private material | Planned |
| **Persistent services and data** | Optional rootless Podman prerequisite and per-run OpenCode sandbox (not a service) | One harmless local service: restricted network, user-level lifecycle/restart, volume ownership, secret injection and backup/restore; decide Quadlet vs Compose in an ADR | Planned |
| **OS settings** | Platform detection and approved login-shell change | One reversible OS preference per supported platform with before/after inspection, consent and no-op rerun | Planned |
| **Backup and disaster recovery** | Reconstructible public source and documented local-only boundaries | From a clean disposable machine/HOME, recover approved config, synthetic encrypted state and one service volume using independently backed-up recovery material | Planned |

**Suggested order:** encrypted values → encrypted files/history → local identity
and recovery → full configuration layering → persistent service → OS setting
and GUI application → explicit upgrades/drift → end-to-end disaster recovery.
The order is a recommendation, not a dependency that blocks independent POCs.

### Capability POC acceptance contract

Every new POC should record:

1. **Question:** what architectural choice is being validated, and what would
   make the POC unsuccessful?
2. **Scope:** smallest representative example, platform(s), chosen owner/tool,
   and the boundary between public, optional private and local-only state.
3. **Safety:** read-only preview, explicit per-operation approval, denied or
   unavailable prerequisites, existing-path conflicts and no silent overwrite.
4. **Repeatability:** already-correct no-op, refusal, failure, clean rerun,
   and recovery/rollback where state can be changed.
5. **Evidence:** synthetic tests in isolated homes, manual Linux/macOS checks
   where relevant, and a linked decision/PR updating status.

For encrypted data, additionally prove **ciphertext-only first commit and
history**, a missing-key failure and a fresh-machine restore. Never exercise
POCs with real credentials. No automatic syncing, identity copying or background
watchers are authorised by completing an encryption POC.

Private profiles must also cover public-only setup, denied/unavailable sources,
explicit selection, dirty/diverged checkouts, effective mise precedence,
overlapping-target refusal and isolation from public CI/Pages. Use synthetic
private fixtures; never use employer repositories or credentials.

## Track B — Tools, applications and services

This is an **adoption/inventory track**, not a second architectural roadmap.
New rows should link to an already-proven capability; if a tool reveals a
missing mechanism, add that mechanism to Track A first. The actual pinned CLI
versions are owned by [the machine manifest](../scripts/setup/mise.toml),
not duplicated here.

| Kind | Example or current adoption | State | Capability used / outstanding |
| --- | --- | --- | --- |
| Core setup | Git, curl prerequisite, mise, Zsh | Implemented baseline | Bootstrap, packages and machine-local shell choice |
| CLI developer tools | Neovim, Zellij, zoxide, ripgrep, fd | Implemented | Declarative pinned CLI tools |
| Shell configuration | Zsh startup, aliases and Powerlevel10k theme/config | Implemented (theme opt-in) | Managed files and optional pinned Git dependency; see [Zsh guide](guides/zsh.md) |
| Repository development tooling | shfmt, ShellCheck, Lefthook, formatting/lint scripts and CI | Implemented; opt-in hooks | Separate checkout-only tool manifest; see [development](guides/development.md) |
| Isolated on-demand command | OpenCode sandbox on Pop!_OS | Implemented, manual approval required | Rootless Podman and Git-scoped mount; see [OpenCode guide](guides/opencode.md) |
| Desktop applications | Ghostty and other GUI tools where needed | Individual installation/configuration varies; broader adoption planned | GUI packaging POC and per-app config deployment |
| Additional personal configs | Neovim, Zellij, Ghostty and other reviewed dotfiles | Incremental migration planned | Managed files; avoid linking placeholder directories |
| Private per-device settings | Explicitly selected non-public profile; local-only overrides | Full profiles planned | Private precedence and machine identity |
| Long-running home services | For example Jellyfin or Radarr, only if wanted on a machine | Not implemented | Persistent service POC; platform-specific, opt-in |
| Network/VPN-related workloads | Only when a clear workload and isolation model is chosen | Not designed | Service networking, privilege and secret-injection review |

Do **not** treat every tool as a host CLI, every application as a container,
or every personal machine as a service host. Host CLI tools, GUI apps,
short-lived sandboxed commands and persistent services have different lifecycle
and trust requirements. See [applications and containers](architecture/applications.md).

### How to add an item

- **New mechanism?** Add a small capability POC in Track A, test it, then adopt
  it for real applications.
- **Another tool using a proven mechanism?** Add an exact pinned manifest entry
  or reviewed config in its normal location and a focused PR/manual test plan;
  update Track B only when the inventory category materially changes.
- **Secrets or private content?** Do not copy into this public repo by default.
  Follow [secrets](architecture/secrets.md) and
  [private configuration](architecture/private-configuration.md); personal
  private Git does not automatically authorise storing work-owned material.

## Delivery conventions

Each feature should be a small PR with a copyable manual test plan. Tests
must verify preview/no-change, refusal, conflicts and repeat runs, and must
not modify real homes, credentials or employer resources. Implemented POCs
should update this roadmap and the relevant human-facing guide/ADR.

- [Initial scaffold PR](https://github.com/daniel-price/dotfiles/pull/1)
- [Mise architecture decision PR](https://github.com/daniel-price/dotfiles/pull/2)
- [Detailed original implementation plan](reference/scaffold-roadmap.md) —
  historical/agent-oriented, not the authoritative current checklist
