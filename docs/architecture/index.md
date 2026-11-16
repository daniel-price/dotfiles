# Architecture and tool choices

The repository deliberately has a small orchestration layer and lets
specialised tools do most of the work. **This is the intended architecture,
not a list of installed or working features.**

| Responsibility | Chosen or proposed owner | Status |
| --- | --- | --- |
| Fresh setup | Bash `scripts/bootstrap.sh` | Installs missing `zsh`, `curl` and pinned mise after individual approval |
| Recurring update | Bash `scripts/update.sh` | Read-only scaffold |
| Runtime and suitable developer tool versions | mise | Installer implemented; tool declarations and provisioning planned |
| Checkout development tools and shell Git hooks | mise + Lefthook | Implemented; opt-in developer setup |
| Managed dotfiles and templating | Native mise dotfiles | Planned, requires validation |
| Encrypted values and tracked files | age through mise | Planned; separate mechanisms |
| Optional private config | Separately authorised Git repo and selected profile | Planned; not connected |
| Machine-local identities and overrides | Outside Git | Policy only |
| System packages, Pop!_OS | apt | Planned |
| System packages and apps, macOS | Homebrew | Planned; never use on Pop!_OS |
| Interactive shell | zsh | Planned configuration |
| Long-running services | Containers where justified | Direction only; no implementation |

## Design boundaries

- **Bash** handles OS detection, precise prompts, ordering and reports.
- **Mise** will own declared tool versions and approved dotfile targets; avoid
  another general-purpose dotfile manager or custom symlink machinery.
- **Git** stores reviewable source. The optional private configuration repo
  and mise's encrypted tracked-file history are **distinct Git stores**.
- **Layering** should compose public defaults, explicitly enabled private
  additions/overrides and then machine-local state. The exact mise merge
  and file-target behaviour must be tested before implementation.
- **Machine-local state** (age recovery identities, private SSH keys, secrets
  not deliberately encrypted for sharing, local overrides) stays out of the
  public repository.
- **Containers** are for services needing isolation, not automatically every
  command-line tool or desktop application.

## Read next

- [Operating systems](platforms.md)
- [Public, private and local configuration](private-configuration.md)
- [Secrets and encryption](secrets.md)
- [Applications and containers](applications.md)
- [Repository layout](repository-layout.md)
- [ADR-0001: choose mise](../decisions/0001-mise-age.md)
- [Historical scaffold architecture](../reference/scaffold-architecture.md) —
  implementation details and earlier investigations, not current instructions
