# Machine profiles and optional modules (native mise)

The public `dotfiles` repository provides **Base** setup. Each machine then
selects any optional mise environments/modules it needs. A module can install
tools, manage packages or services, and configure shell variables and dotfiles.
A module is **not** a Git repository per tool.

This uses [mise machine modules](https://mise.jdx.dev/bootstrap/modules.html),
[config environments](https://mise.jdx.dev/configuration/environments.html),
[repository management](https://mise.jdx.dev/bootstrap/repos.html),
and [conf.d folders](https://mise.jdx.dev/configuration.html#conf-d-folders).
Requires mise **2026.11.9+**. It is opt-in: Base works without private Git access.

## How the three machines are configured

Bootstrap first, then create the following **local, untracked** file on each
machine: `~/.config/mise/miserc.local.toml`.

| Machine | File contents | Effective setup |
| --- | --- | --- |
| Work Mac | `env = ["work"]` | Base + work-only private scripts |
| Personal Linux laptop | `env = ["personal", "opencode"]` | Base + pinned OpenCode |
| Home server | `env = ["home-server", "opencode", "radarr"]` | Base + OpenCode + private Radarr configuration |

The shared Base lives in `scripts/setup/mise.toml`. Install the public repository at
`~/.dotfiles` (the documented bootstrap location); mise's dotfile sources
use this stable path. Bootstrap symlinks it
to `~/.config/mise/config.toml` and deploys the **unselected**
`config.opencode.toml` file next to it. Merely having a module file on disk
does **not** activate or install it. No environment selected means Base only.

OpenCode's native host CLI is **unsandboxed**; prefer the existing
`opencode-sandbox` launcher for untrusted projects. Its version pin lives
only in `.config/mise/config.opencode.toml`, not in Base.

## Work-only commands in an approved private repository

A work-only machine-local configuration, not committed to the public repo:

```toml
# ~/.config/mise/config.work.local.toml
[bootstrap.repos]
"~/.local/share/dotfiles/work-scripts" = { url = "git@github.com:APPROVED-ORG/WORK-SCRIPTS.git", ref = "main" }

[env]
_.path = ["~/.local/share/dotfiles/work-scripts/bin"]
```

The **employer-approved** private repository can have a `bin/` directory
with executable Bash scripts, e.g. `,logs` or `,deploy`. Mise clones
it when `work` is selected, and only activated shells on that machine
add the directory to PATH. No work code, repository URL, or credentials are
put in public dotfiles. Do **not** upload work-owned files to a personal GitHub
account unless explicitly authorised.

## Radarr from a private Git repository

Keep the repository URL **on the home server only**:

```toml
# ~/.config/mise/config.radarr.local.toml
[bootstrap.repos]
"~/.config/mise/conf.d/radarr" = { url = "git@github.com:YOUR-ACCOUNT/PRIVATE-RADARR-CONFIG.git", ref = "main" }
```

The private repository contains `mise.radarr.toml` (not plain `mise.toml`)
and, if using Compose, a `compose.yaml`. Mise loads `mise.radarr.toml`
only when the `radarr` environment is selected:

```toml
# Private repository: mise.radarr.toml
[bootstrap.compose.radarr]
project_dir = "{{ config_root }}"
files = ["compose.yaml"]
```

This illustrates the module mechanism, **not a complete Radarr deployment**:
the private Compose file must define a valid service, secure credentials,
persistent media/data volumes and an appropriate container engine. A private
Git repository is not encryption; keep secrets out of Git.

Mise discovers a newly cloned `conf.d` folder on its **next invocation**.
Our `,bootstrap` runs the selected repository phase first, then re-invokes
mise to preview/apply the resulting configuration.

## Applying and updating

```sh
,bootstrap                         # Base + selected modules, reviewed interactively
mise -C / config ls               # See which native config files actually loaded
mise -C / ls --current            # See selected pinned tools
mise -C / bootstrap --dry-run     # Preview selected resources without changing anything
mise -C / bootstrap repos update --dry-run  # Preview private repo updates
```

Bootstrap retains explicit confirmations for Base actions. With a local
module selection, it previews and asks before cloning/updating private
repositories and before applying modules. The final native `mise bootstrap`
retains mise's own confirmations (we do not pass `--yes`).

If you deselect a module, **existing installations are not automatically
uninstalled**, and private repository checkouts are never deleted by mise.
Preview `mise bootstrap unapply NAME --dry-run`, and review tool or package
cleanup separately. Never apply destructive Compose removal without backups.

Mise refuses to update Git checkouts that contain uncommitted work; changes
must be reviewed and intentionally applied.

## Migrating an existing legacy Profile installation

If you previously used `,profile --name ... --repo ... --apply`, its checkout,
managed registry and generated manifest still exist. Legacy setup remains
supported temporarily to prevent a shell configuration regression.

1. Record the profile's executable paths, aliases, environment values and
   app links; move the declarations into the relevant native module or
   a local `config.<env>.local.toml`.
2. Preview `,profile --name NAME --deactivate`, then approve deactivation
   with `--apply`. Do this for **all** active legacy profiles.
3. Create the machine's `miserc.local.toml` selection and its approved
   private module declarations, then run `,bootstrap` again.
4. Validate `mise -C / config ls`, shell aliases, PATH, and any private
   commands in a **new shell**. Delete old profile checkouts only after
   you've validated migration and no longer need them.

While the old registry exists, bootstrap deliberately skips native modules.
Legacy profile activation is deprecated and should not be used for new setups.

## Safety and limitations

- The normal Base setup needs Git and works without private repository access.
- Only explicitly selected environments load their optional declarations.
- Remote repositories require configured SSH access and approval before
  cloning; their content can run commands, so review it before trusting.
- Existing app files or symlinks are not silently overwritten; test on a
  disposable HOME before using work or server machines.
- Use local configuration files for private URLs and authorised work settings.
  Store cryptographic identities and secrets in dedicated secure storage.
- Work and home-server roles can stay local, without creating public fake
  definitions for them.

See [configuration architecture](../architecture/configuration.md).
