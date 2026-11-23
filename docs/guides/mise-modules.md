# Mise-native machine modules

**Status:** Base and sandbox-only OpenCode module implemented. Private work
scripts and Radarr are documented examples pending validation.

## How it fits together

- **Base** tool versions are defined once in `scripts/setup/base-tools.toml`
  and loaded by both `scripts/setup/mise.toml` (bootstrap-only packages and
  dotfiles) and `scripts/setup/global-mise.toml` (normal global mise config).
  `,bootstrap` continues to preview and approve each Base install. It also
  links the global config, shared pins and optional OpenCode module into
  `~/.config/mise/`. All sources are public dotfiles files, not copies.
- **Modules** are mise `config.<name>.toml` and
  `config.<name>.local.toml` files. Selection is a local setting, not a
  separate Git repository or a custom-generated merged manifest.
- **Private resources** are declared only in `*.local.toml` on the authorised
  machine, or in an approved private checkout. Never publish work-owned
  code in a personal Git repository.

The public `opencode` module **only exposes the rootless Podman launcher**
`modules/opencode/bin/opencode-sandbox` on `PATH` using mise's native
`[env] _.path`. There is **no native host OpenCode installation**, either
in Base or this module. The launcher remains unavailable in a fresh work
shell where `opencode` is not selected. It prompts before installing a
missing Podman prerequisite and before pulling, building or running the
container; merely selecting the module installs nothing. This module
assumes the documented checkout path `~/.dotfiles`.

## Choose modules for each machine

Create this **untracked, machine-local file** after `,bootstrap` deploys the
mise global config:

`~/.config/mise/miserc.local.toml`

| Device | Contents |
| --- | --- |
| Work | `env = ["work"]` |
| Personal | `env = ["personal", "opencode"]` |
| Home server | `env = ["home-server", "opencode", "radarr"]` |

`personal`, `work` and `home-server` are selection names. They do not
need empty public module files; optional local configuration can be added
under the matching `config.<env>.local.toml` file. Only `opencode` has a
public module at present.

From a **new Zsh session**, check what mise loaded:

```sh
mise config
mise ls --current
mise bootstrap --dry-run
```

Only after reviewing the preview, run `mise bootstrap` interactively.
This separate action is deliberate: the main `,bootstrap` retains its
individual Base approvals, so selecting a module does not silently
install Base tools you previously declined. `mise bootstrap` considers
*all* currently selected resources, including missing Base tools and
packages; inspect the plan before accepting. `auto_install = false`
continues to prevent automatic installation on shell startup.

## Private work scripts

Keep this **only on the work laptop**:

```toml
# ~/.config/mise/config.work.local.toml
[bootstrap.repos]
"~/src/approved-work-scripts" = { url = "git@github.com:APPROVED-OWNER/APPROVED-REPO.git", ref = "main" }

[env]
_.path = ["~/src/approved-work-scripts/bin"]
```

Replace the placeholder URL with an employer-approved repository. An SSH
credential with access is required. With `env = ["work"]`, preview the
checkout with `mise bootstrap repos apply --dry-run` and then run
`mise bootstrap repos apply` interactively. A new mise-activated shell
then exposes its `bin/` commands. No other machine selects or fetches it.

## Private Radarr configuration (home server only)

Mise's remote Git `include` cannot import machine-management sections
such as `[dotfiles]`, so use native `[bootstrap.repos]` plus a managed
local module symlink. Keep private repo URLs on the server:

```toml
# ~/.config/mise/config.home-server.local.toml
[bootstrap.repos]
"~/src/private/radarr-config" = { url = "git@github.com:PRIVATE-OWNER/radarr-config.git", ref = "main" }

[dotfiles]
"~/.config/mise/config.radarr.local.toml" = { source = "~/src/private/radarr-config/mise.toml", mode = "symlink" }
```

The private repository supplies `mise.toml` containing the Radarr setup,
not secrets. The user must configure credentials outside Git. On first
setup:

1. Set `env = ["home-server", "opencode", "radarr"]` locally.
2. Preview and approve `mise bootstrap repos apply` to clone the private repo.
3. Preview and approve `mise bootstrap dotfiles apply` to link its module.
4. Start a new shell, preview `mise bootstrap --dry-run`, then approve
   `mise bootstrap` to apply the selected modules.

The first run is intentionally staged: the private module file cannot be
loaded until the approved checkout and symlink exist. Review all private
module code before approving; these configurations can execute commands.
Actual Radarr service/container setup, persistence, secrets and updates
must be designed and tested separately; no Radarr service is installed
by this public repository.

## Safety and removal

- **Conflicts are preserved.** `,bootstrap` must not replace a foreign
  `~/.config/mise/config.toml` or module file without explicit resolution.
  If a link cannot be applied, inspect it manually; do not use `--force`
  on unrelated configuration.
- **Deselecting:** Edit `miserc.local.toml` to remove an environment.
  This stops loading it but **does not uninstall its tools or delete repos**.
  For resources managed by the module, preview
  `mise bootstrap unapply <module> --dry-run` before approving removal.
  Private repository checkouts remain until explicitly reviewed and deleted.
- Never commit `miserc.local.toml`, private repo URLs, API keys, or private
  data to the public repository. Use authorised work storage.

See official mise [machine modules](https://mise.jdx.dev/bootstrap/modules.html),
[repos](https://mise.jdx.dev/bootstrap/repos.html),
[environment files](https://mise.jdx.dev/configuration/environments.html),
and [bootstrap](https://mise.jdx.dev/bootstrap.html).
