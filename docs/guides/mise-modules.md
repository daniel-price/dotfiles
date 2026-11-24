# Mise modules

Select modules in `~/.config/mise/miserc.local.toml`:

| Machine | Contents |
| --- | --- |
| Work | `env = ["work"]` |
| Personal | `env = ["personal", "opencode"]` |
| Home server | `env = ["home-server", "opencode"]` |

Only `opencode` has a public optional module. It exposes the sandbox launcher, not native OpenCode.

```sh
mise config
mise ls --current
mise bootstrap --dry-run
mise bootstrap
```

## Private modules

Example machine-local configuration:

```toml
# ~/.config/mise/config.work.local.toml
[bootstrap.repos]
"~/src/approved-work-scripts" = { url = "git@github.com:APPROVED-OWNER/APPROVED-REPO.git", ref = "main" }

[env]
_.path = ["~/src/approved-work-scripts/bin"]
```

```sh
mise bootstrap repos apply --dry-run
mise bootstrap repos apply
```

Use authorised repositories only. Private module integration is pending validation. Removing an environment from the selection does not uninstall its resources.

[Mise documentation](https://mise.jdx.dev/bootstrap/modules.html)

## Discover personal profiles

Run `,profiles` after authenticating with `gh auth login`. Select one or more
repositories owned by the authenticated account named `.dotfiles-profile-personal`
or `.dotfiles-profile-personal-<suffix>`. Each must contain a matching
`mise.personal.toml` or `mise.personal-<suffix>.toml` at its root.

Review each checkout before approving trust and selection. The command preserves
existing environments, never pulls existing checkouts, and previews tools and
dotfiles before separately asking to install or apply them. Deselect manually
in `~/.config/mise/miserc.local.toml`; nothing is automatically removed.
