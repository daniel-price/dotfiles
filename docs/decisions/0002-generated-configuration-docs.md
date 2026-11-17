# ADR-0002: Generate configuration references at documentation build time

**Status:** Accepted
**Date:** 2026-11-17

## Context

Handwritten Zsh and Zellij references repeated settings and keybindings
already declared in the source files. This duplication became stale as the
configurations changed. Published references should describe what is currently
configured, not narrate migration history.

## Decision

Generate configuration references when building documentation, not in Git.
Use one local entrypoint (`scripts/docs/generate.py`) to invoke small,
format-specific extractors for Zsh and Zellij, plus the standard-library
TOML parser for the machine and checkout development tool manifests. Also generate\na command reference from an explicit allowlist of scripts' side-effect-free\n\`--help\` output, invoked with isolated HOME, no TTY and a timeout. Read the checked-in configuration
as data, without executing it. Derive aliases, keybindings and simple settings
from declarations; keep only short `# doc:` / `// doc:` annotations where
user-facing behaviour needs clarification. Omit historical migration details.

The same local build script generates references for CI and GitHub Pages.
Generated files are ignored, removed after each build, and never maintained
by hand.

## Consequences

Changing a binding, alias, tool version or CLI help string updates the published reference on the next build.
Extractors intentionally support the project's current source syntax, rather
than becoming general-purpose language parsers. Fail loudly on unsupported
structures or orphaned annotations, and test the extractors when config syntax
changes. Narrative architecture and installation guides remain handwritten.
