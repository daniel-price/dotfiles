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

Future machine-specific non-secret profiles will be committed only once their
layout is designed; local sensitive files stay outside Git. The normal dotfiles
Git checkout is **not** the same thing as the optional mise tracked-file history.

Reference material lives under `docs/reference/` and can be much denser than
the main handbook. It is still **public** and must not contain secrets.
