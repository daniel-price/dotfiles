# Platforms

Supported: **Pop!_OS / Debian-derived Linux** and **macOS**.

Machine configuration belongs in [`scripts/setup/mise.toml`](../../scripts/setup/mise.toml); the root `mise.toml` is for developing this repository.

## Installed tool inventory

| Component | Linux | macOS |
| --- | --- | --- |
| Git (prerequisite) | Install separately before cloning | Install separately (e.g. Apple Command Line Tools) before cloning |
| curl | Required for mise installation; normally available | Required for mise installation; normally included |
| mise | Verified pinned installer, after approval | Same |
| Zsh (if absent) | apt via mise | Homebrew via mise when necessary |
| Machine CLI tools | Pinned `[tools]` via mise | Same |
| Zsh dotfile | Reviewed `mise dot apply` | Same |
| Login shell | Approved `chsh` | Approved `chsh` |
| Powerlevel10k | Optional pinned Git checkout via mise | Same |

Machine tool **names and versions** are maintained only in the manifest, not in this page. Bootstrap offers missing components individually; it never silently upgrades installed tools. Conflicting files are preserved.

## Checkout development tools

The root `mise.toml` contains checkout-only tools (Lefthook, shfmt and ShellCheck). They are not installed by machine bootstrap; see [development](../guides/development.md).

## Other platform behaviour

The reviewed Zsh startup activates mise and zoxide when installed; it resolves the managed config even through a symlink. The theme is optional. Setting the login shell affects future sessions, not the running Bash terminal.

Rootless [OpenCode](../guides/opencode.md) and [optional Podman setup](../guides/podman.md) are currently **Linux-only**. Long-running container services, OS preferences and full private configuration remain planned; see the [roadmap](../roadmap.md).

To inspect or undo eligible managed items, use the [cleanup commands](../getting-started/index.md#common-follow-up-tasks). The cleanup command is intentionally selective, not a full uninstall.
