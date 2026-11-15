# Repository layout

This is a map of **what exists**, with future responsibilities labelled.

```text
dotfiles/
├── README.md                # Short GitHub entry point
├── AGENTS.md                # Brief agent rules; links to this handbook
├── bootstrap.sh             # Read-only scaffold today
├── update.sh                # Read-only scaffold today
├── scripts/lib/             # OS detection and interactive confirmation
├── .config/
│   ├── mise/config.toml     # Empty [tools] table
│   ├── nvim/                # Marker only
│   ├── zellij/              # Marker only
│   └── ghostty/             # Marker only
├── tests/                   # Dependency-free Bash scaffold tests
├── docs/                    # Canonical website Markdown
├── zensical.toml            # Static-site configuration
└── .github/workflows/docs.yml # Build/Pages workflow
```

The application directories currently contain placeholders, **not deployable
configurations**. Do not link the whole `.config` tree.

**Planned separate sources** (not currently connected or cloned):

```text
public dotfiles repo     -> shared defaults, safe docs, bootstrap
optional private repo   -> approved non-public profiles, separate checkout
machine-local state     -> private identities, keys and host overrides
optional mise history   -> encrypted tracked-file snapshots (distinct source)
```

No private remote, path, repository name or work-specific details belong in
this public repo. Public setup and Pages builds must never require private
access. For work-related material, use employer-approved storage rather than
assuming a personal private repo is acceptable. See
[configuration layers](private-configuration.md).

Reference material lives under `docs/reference/` and can be much denser than
the main handbook. It is still **public** and must not contain secrets.
