# ADR-0001: Use mise and age for development environment management

**Status:** Mise installation implemented; tool, dotfile and encryption work pending
**Date:** 2026-11-15

## Context

The setup spans Pop!_OS and macOS, and should use established tools for
runtimes, dotfile deployment and encrypted settings, without growing a custom
configuration manager. The main repository must remain public.

## Decision

Use **mise** for runtimes, developer tools and native dotfile deployment; use
**age through mise** for suitable encrypted settings. Keep Bash small and
responsible for OS checks, ordering, per-operation consent and reporting.
Do not introduce chezmoi or SOPS by default.

There are two distinct mise encryption workflows: encrypted environment values
and encrypted whole-file tracked history. The latter uses a separate Git store,
not this public source checkout by default. No automatic history syncing,
watchers, key copying or ciphertext publication until verified in an isolated
prototype.

## Alternatives considered

- **Chezmoi + age:** mature specialised dotfile handling, but duplicates mise's
  intended dotfile responsibilities.
- **SOPS + age:** useful structured secret encryption, but adds a second
  management workflow for the current use case.
- **Custom symlink scripts:** additional code and conflict handling to maintain.

## Consequences

One primary tool reduces coordination and conceptual overhead. Mise dotfiles
and encryption are newer capabilities, so their version and conflict/restore
semantics must be tested carefully. Encryption is **not yet configured**;
machine-specific SSH private keys and age recovery identities stay outside Git.

Bootstrap pins mise `v2026.11.9`. With separate approval for download and
execution, it downloads that immutable GitHub Release installer to a temporary
file, verifies its committed SHA-256, and runs it with GitHub-only release
downloads. The release installer verifies the selected binary before writing
`~/.local/bin/mise`. Existing mise installations are not upgraded or replaced.
Bootstrap does not activate mise, trust configuration, install a tool, or
modify shell startup files.

## Follow-up

See [the implementation roadmap](../roadmap.md) and
[Secrets architecture](../architecture/secrets.md). Revisit this ADR if a
prototype demonstrates a concrete blocker.
