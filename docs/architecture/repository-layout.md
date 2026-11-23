# Repository layout

| Path | Purpose |
| --- | --- |
| `bin/,bootstrap` | Sole machine bootstrap command (run after Git clone) |
| `setup/` | Machine setup, updates and cleanup |
| `dev/` | Repository maintenance only: tooling, tests, generators and experiments |
| `dev/scripts/` | Repo formatting, linting, hooks, CI and docs |
| `dev/lib/` | Helpers used only by developer scripts |
| `lib/` | Shared Bash helpers (not standalone commands) |
| `setup/mise.toml` | Machine packages, pinned tools and dotfiles |
| `dev/mise.toml` | Checkout-only development tooling |
| `.config/` | Reviewed source configuration |
| `bin/` | Shared personal executables |
| `modules/opencode/bin/` | Optional sandbox-only OpenCode launcher selected through mise |
| `containers/` | Optional, isolated workload definitions |
| `dev/tests/` | Synthetic/no-host-change verification |
| `.github/`, `lefthook.yml` | Root-level files required for workflow and hook discovery |
| `docs/` | Handbook, decisions and history |

Run developer tasks with `mise -C dev run check` (or `format`/`test`). Runtime commands in `bin/` must not depend on developer tools. Only deploy **reviewed** configs; do not link placeholder directories. Private machine modules and age identities stay outside Base. See [architecture](index.md) and [roadmap](../roadmap.md).
