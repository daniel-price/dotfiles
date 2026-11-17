# Repository layout

| Path | Purpose |
| --- | --- |
| `get-started.sh` | Standalone bootstrap before Git clone |
| `scripts/setup/` | Machine setup, updates and cleanup |
| `scripts/dev/` | Repo formatting, linting, hooks, CI and docs |
| `scripts/lib/` | Shared Bash helpers (not standalone commands) |
| `scripts/setup/mise.toml` | Machine packages, pinned tools and dotfiles |
| `mise.toml` | Checkout-only development tooling |
| `.config/` | Reviewed source configuration |
| `bin/` | Personal executables, including `opencode-sandbox` |
| `containers/` | Optional, isolated workload definitions |
| `tests/` | Synthetic/no-host-change verification |
| `docs/` | Handbook, decisions and history |

Only deploy **reviewed** configs; do not link placeholder directories. Separate optional/private sources and age identities remain outside this public repo. See [architecture](index.md) and [roadmap](../roadmap.md).
