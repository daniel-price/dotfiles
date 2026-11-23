# Configuration: Base, optional modules and private repositories

Two concerns are kept separate: **what is selected on a machine**, and
**where the selected configuration is stored**.

| Layer | What it owns | Source |
| --- | --- | --- |
| Base | Tools, packages and common dotfiles on every machine | Public `scripts/setup/mise.toml`, linked as global config |
| Module | Optional tools, repositories, files and services | Mise environment `config.<name>.toml` or `conf.d/<name>/mise.<name>.toml` |
| Machine selection | Which modules are enabled | Local `~/.config/mise/miserc.local.toml` |
| Private config | Work scripts, home-server apps, non-public settings | Approved local TOML and opt-in private Git repos |

This is native mise [machine modules](https://mise.jdx.dev/bootstrap/modules.html),
[environments](https://mise.jdx.dev/configuration/environments.html)
and [repository setup](https://mise.jdx.dev/bootstrap/repos.html), rather
than a bespoke configuration composer. Base works alone and has no private
repository prerequisites.

The public OpenCode module is installed **only** for machines selecting
`opencode`. Work-only scripts can be cloned with `[bootstrap.repos]`
and added to PATH with `[env] _.path`, both declared in a machine-local
`config.work.local.toml`. A private Radarr repository can be cloned into
`~/.config/mise/conf.d/radarr`, containing a `mise.radarr.toml`
environment-specific module.

**Private** means Git repository visibility, not encryption. Work-owned
content requires employer-approved source control and machine policies.
Secrets, access tokens and decryption keys remain outside plaintext Git.

## Compatibility and rollout

The older `,profile` workflow remains available only for explicit
deactivation and migration; it uses its own registry and merged tool manifest.
Existing legacy selections still load until deactivated. `,bootstrap`
skips native optional module setup while that registry exists to avoid
config conflicts or surprises. The legacy composer will be removed after
native migration is validated on the actual machines.

Mise's native `bootstrap unapply` handles some resources but does **not**
uninstall shared tools or delete cloned Git repositories, and Compose
needs explicit state changes for teardown. All such cleanup remains reviewed.

See the [machine profile guide](../guides/profiles.md).
