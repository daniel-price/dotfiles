# Repository layout

Scripts are organised by **who runs them and when**, rather than by language or
tool. Machine setup is distinct from developing this repository; personal
commands are distinct from both.

| Path | Responsibility |
| --- | --- |
| `get-started.sh` | Standalone stage-zero installer: checks Git, clones the public checkout and asks before running bootstrap. |
| `scripts/setup/` | Machine lifecycle: `bootstrap.sh`, `deploy-zsh-config.sh`, `apply-private-overlay.sh` and preview-first `cleanup.sh`. |
| `scripts/dev/` | Checkout maintenance: formatting, linting, Git hooks, documentation builds, dependency setup and CI checks. |
| `scripts/lib/` | Source-only Bash helpers shared by setup and development scripts. |
| `bin/` | Reviewed everyday commands, currently the executable Linux-only `opencode-sandbox` launcher. |
| `scripts/setup/mise.toml` | Declarative machine packages, pinned tools and the opt-in zsh dotfile entry; deliberately separate from developer tooling. |
| `.config/` | Reviewed home configuration: zsh startup (which adds the repo's `bin/` to PATH) and future application defaults. |
| `containers/opencode/` | Reviewed minimal OpenCode image recipe; built only after separate interactive approval, without the developer checkout as build context. |
| `tests/` | Temporary-fixture and interactive integration tests, never host-changing by default. |
| `docs/` | Current handbook and separately labelled historical planning notes. |
| `.github/` | CI orchestration and pull request template. |
| `mise.toml`, `lefthook.yml`, `zensical.toml` | Root-level tool configuration, retained where standard discovery expects it. |
| `README.md`, `AGENTS.md` | Human and agent entry points. |

A user bootstrapping a machine should not need the development-only tools from
`scripts/dev/`. Git hooks and CI should call those same development scripts,
not duplicate tool commands. A script under `scripts/lib/` should be sourced
rather than executed; do not deploy it as a shell utility.

Keep the standalone `get-started.sh` in the root because it is downloaded
**before the repository is cloned**. It recognises current
`scripts/setup/bootstrap.sh` checkouts and older `scripts/bootstrap.sh` or
root-level `bootstrap.sh` checkouts, without updating them implicitly.

There is currently **no recurring update command**. Git synchronisation,
version upgrades and broader dotfile deployment remain explicit future work.

Only the reviewed `.config/zsh/zshrc` is deployable today through native mise dotfiles and an explicit safety preflight. Application
placeholder directories are not working configurations and must not be linked
wholesale. Keep repo-only development settings outside `.config/`.

**Planned separate sources** (not currently connected or cloned):

| Source | Planned contents |
| --- | --- |
| Public dotfiles repo | Shared defaults, safe docs and bootstrap. |
| Optional private repo | Approved non-public profiles in a separate checkout. |
| Machine-local state | Private identities, keys and host overrides. |
| Optional mise history | Encrypted tracked-file snapshots in a distinct source. |

No private remote, path, repository name or work-specific details belong in
this public repo. Public setup and Pages builds must never require private
access. Work-related material needs employer-approved storage. See
[configuration layers](private-configuration.md).

Historical reference notes are public too and must never contain secrets.
