# Repository layout

| Path | Purpose |
| --- | --- |
| `bin/,bootstrap` | Sole machine bootstrap command (run after Git clone) |
| `scripts/setup/` | Machine setup, updates and cleanup |
| `scripts/dev/` | Repo formatting, linting, hooks, CI and docs |
| `scripts/lib/` | Shared Bash helpers (not standalone commands) |
| `scripts/setup/mise.toml` | Machine packages, pinned tools and dotfiles |
| `mise.toml` | Checkout-only development tooling |
| `.config/` | Reviewed source configuration |
| `bin/` | Shared personal executables |
| `modules/opencode/bin/` | Sandbox-only OpenCode launcher, exposed via the optional mise environment |
| `containers/` | Optional, isolated workload definitions |
| `tests/` | Synthetic/no-host-change verification |
| `docs/` | Handbook, decisions and history |

Only deploy **reviewed** configs; do not link placeholder directories. Optional Profile checkouts and age identities stay outside Base. See [architecture](index.md) and [roadmap](../roadmap.md).
