# Operating systems and machine-specific configuration

The shared baseline covers **Pop!_OS** and **macOS**. Differences should be
explicit instead of hidden inside a monolithic installation script.

| Concern | Pop!_OS | macOS |
| --- | --- | --- |
| OS detection | Debian/Ubuntu family, including `ID_LIKE` | Darwin |
| System packages | apt | Homebrew |
| Runtime and dotfile declarations | mise installed on approval; declarations planned | mise installed on approval; declarations planned |
| Interactive shell | zsh (planned) | zsh (planned) |
| Bootstrap language | Bash | System Bash 3.2-compatible |

A missing package must be checked and approved before installation. An
existing tool should not be upgraded merely because an update script ran.

## Where differences belong

- **Shared public settings:** versioned config and templates in this repo,
  eventually deployed by mise.
- **Platform variants:** explicit, versioned platform-specific config **when
  introduced**; there is not yet an implemented per-platform directory.
- **Private profiles:** an optional, separately authorised Git repository
  may supply non-public personal/work settings on deliberately selected
  machines; this is not currently implemented.
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
