# Repository layout

This is a map of **what exists**, with future responsibilities labelled.

| Path | Responsibility |
| --- | --- |
| `README.md`, `AGENTS.md` | Human and agent entry points. |
| `get-started.sh` | Standalone download: ensure Git and acquire the checkout. |
| `scripts/bootstrap.sh` | Installs missing `zsh`, `curl`, pinned mise and Neovim after individual approval. |
| `scripts/provision-tool.sh` | Installs one reviewed mise-declared tool after confirmation. |
| `scripts/apply-private-overlay.sh` | Previews and applies one explicitly selected private directory symlink. |
| `scripts/deploy-zsh-config.sh` | Previews and applies the reviewed zsh startup file after confirmation. |
| `scripts/install-ghostty.sh` | Installs Ghostty with apt/Homebrew after per-OS confirmation. |
| `scripts/update.sh` | Read-only checkout scaffold today. |
| `scripts/` | Visible checkout scripts for setup, shared checks and docs builds. |
| `scripts/lib/` | OS, confirmation and mise location/trust helpers. |
| `.config/zsh/zshrc` | Reviewed public zsh startup file that activates mise. |
| `.config/` | Other future managed user dotfiles: Neovim, Zellij and Ghostty placeholders. |
| `mise.toml`, `lefthook.yml` | Project development tooling and hook configuration. |
| `zensical.toml` | Documentation-site configuration. |
| `tests/` | Scaffold checks and disposable hook integration tests. |
| `docs/` | Canonical handbook Markdown. |
| `.github/` | Workflow orchestration and PR template. |

Keep executable project code in visible `scripts/`; there is no separate
hidden `.scripts/` directory. Reserve `.config/` for configuration intended for
the user's home directory. Repository tooling stays in its usual discovery
locations rather than being mixed with those future deployed files.

The root keeps six visible files: the two entry documents, the standalone
download, and three tool configurations. The checkout's bootstrap and update
commands live with the other scripts.

The application directories currently contain placeholders, **not deployable
configurations**. Do not link the whole `.config` tree.

Development tooling lives in the root `mise.toml` and `lefthook.yml`, with
opt-in hook setup in `scripts/install-hooks.sh`, disposable integration checks
in `tests/hooks.sh`, and Linux/macOS CI in `.github/workflows/shell.yml`. See
[development](../guides/development.md); this is separate from machine setup.

**Planned separate sources** (not currently connected or cloned):

| Source | Planned contents |
| --- | --- |
| Public dotfiles repo | Shared defaults, safe docs and bootstrap. |
| Optional private repo | Approved non-public profiles in a separate checkout. |
| Machine-local state | Private identities, keys and host overrides. |
| Optional mise history | Encrypted tracked-file snapshots in a distinct source. |

No private remote, path, repository name or work-specific details belong in
this public repo. Public setup and Pages builds must never require private
access. For work-related material, use employer-approved storage rather than
assuming a personal private repo is acceptable. See
[configuration layers](private-configuration.md).

Reference material lives under `docs/reference/` and can be much denser than
the main handbook. It is still **public** and must not contain secrets.
