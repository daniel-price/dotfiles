# Repository layout

| Path | Purpose |
| --- | --- |
| `src/` | Self-contained runtime |
| `src/home/` | Files deployed into the user's home |
| `src/bin/` | Public commands |
| `src/lib/` | Shared implementation |
| `src/lib/setup/` | Provisioning and lifecycle operations |
| `src/modules/` | Optional modules, including container definitions |
| `src/mise.toml` | Machine provisioning manifest |
| `dev/` | Development tooling, tests and generators |
| `docs/` | Documentation |
| `.github/` | CI and PR metadata |

Deleting `dev/` and `docs/` must not affect the installed environment. Runtime code must not depend on these directories. Root-level configuration is retained only when required by tooling (for example Lefthook).
