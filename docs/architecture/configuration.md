# Configuration: Base and Profiles

Two configuration concepts are supported:

| Term | Meaning | Source |
| --- | --- | --- |
| **Base** | Shared tools, shell defaults and app settings that work without extra repositories | Public `dotfiles` checkout |
| **Profile** | Reusable, optional configuration selected explicitly for a purpose, such as `personal`, `work` or `home-server` | Separate, authorised Git repository |

A device can enable multiple profiles; a profile can be reused across devices. The intended composition is **Base → selected Profiles**, with conflicts explicitly checked rather than silently overwritten. The Base works alone, without profile access or authentication.

**Private** describes Git repository visibility, not a type of configuration. A profile may be public or private; work content still requires employer-approved storage. **Secrets** and cryptographic identities need separate protection—private Git alone is not encryption.

## Current support

The [profile POC](../guides/profiles.md) clones explicitly selected repositories into `~/.dotfiles-profiles/` (outside Base), previews their effective tool and non-secret environment configuration, and asks before activation and each missing-tool installation. New Zsh sessions use the selected profiles' executables, aliases and functions. Application configuration files are linked only to non-conflicting targets. Deactivation is previewable and keeps Git checkouts and installed tools intact.

Profile updates, automatic discovery, general-purpose configuration merges, and rollback of installed software are **not implemented**. Do not assume arbitrary TOML, app settings or shell scripts can be merged.

## Deferred: Local

**Local** would mean per-device configuration, such as monitor layout, hostnames or mount paths, not reusable across computers. There is **no managed Local layer today**; configure these manually until the need justifies another mechanism. See the [roadmap](../roadmap.md).

The previous [one-directory linking utility](../guides/directory-link.md) is a separate, legacy feature; it is not part of Base/Profile composition. [Secrets](secrets.md) and encrypted tracked-file history are also separate concerns.
