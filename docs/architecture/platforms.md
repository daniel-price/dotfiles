# Operating systems and machine-specific configuration

The shared baseline covers **Pop!_OS** and **macOS**. Differences should be
explicit instead of hidden inside a monolithic installation script.

| Concern | Pop!_OS | macOS |
| --- | --- | --- |
| OS detection | Debian/Ubuntu family, including `ID_LIKE` | Darwin |
| System packages | apt | Homebrew |
| Runtime and dotfile declarations | mise (planned) | mise (planned) |
| Interactive shell | zsh (planned) | zsh (planned) |
| Bootstrap language | Bash | System Bash 3.2-compatible |

A missing package must be checked and approved before installation. An
existing tool should not be upgraded merely because an update script ran.

## Where differences belong

- **Shared public settings:** versioned config and templates in this repo,
  eventually deployed by mise.
- **Platform variants:** explicit, versioned platform-specific config **when
  introduced**; there is not yet an implemented per-platform directory.
- **Machine-specific non-secrets:** opt-in local overrides; `local/` and
  `*.local` are ignored now but not automatically loaded.
- **Sensitive identities:** outside the public Git checkout, with secure
  recovery and explicit access decisions.

Avoid embedding hostnames, personal addresses, work settings or actual SSH
private keys in public documentation.
