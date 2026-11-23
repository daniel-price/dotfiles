# Configuration: Base and mise modules

The public dotfiles checkout defines **Base** tools, shell configuration and
defaults. Optional capabilities are selected through mise's native configuration
environments, not a custom profile system.

| Layer | Source | Example |
| --- | --- | --- |
| Base | Public `dotfiles` | Neovim, Zellij and Zsh |
| Optional module | `config.<env>.toml` in public dotfiles | Rootless OpenCode sandbox |
| Private module | Locally approved private repository | Work-only commands, Radarr |
| Machine selection | `~/.config/mise/miserc.local.toml` | `env = ["personal", "opencode"]` |

Mise loads only the selected environments. Optional module binaries can be
exposed with `[env] _.path`, without adding them to Base. Private repositories
are cloned through authorised `[bootstrap.repos]` declarations. No private
credentials or secrets are committed to public Git.

Bootstrap remains interactive and independently usable without any private
repository or credentials. Deselecting an environment stops loading it; it does
not automatically uninstall software or delete checkouts.

Employer-owned code must stay in employer-approved storage. Private Git does
not encrypt secrets; identity keys need separate protection.

See [mise machine modules](../guides/mise-modules.md),
[secrets](secrets.md) and the [roadmap](../roadmap.md).
