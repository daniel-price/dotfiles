# ADR-0003: Separate public, private and local configuration

**Status:** Accepted; one-target overlay prototype implemented, full profiles pending
**Date:** 2026-11-15

## Context

The public dotfiles repository should support multiple OSs without exposing
non-public personal or work-specific files. Ignored local overrides lack a
portable source of truth, but encrypting every non-public file into a public
repo is not always necessary or appropriate.

## Decision

Retain a standalone public baseline. An **optional, separately authorised
private Git repository** may provide selected non-public configuration on
approved machines. Keep keys, identities and host-only state in a third,
machine-local layer outside Git.

The intended priority is **public defaults → approved private profile →
machine-local override**. Treat this as a contract that requires tests of
actual mise configuration precedence and deployment conflicts. Do not install
an optional private layer without explicit consent.

Private configuration is **distinct from mise's encrypted tracked-file
history store**. A private Git repository does not replace secrets management.
Work-related content belongs in employer-approved storage, not automatically
a personal private GitHub account.

## Alternatives

- **Public Git + encryption for everything:** unnecessarily publishes some
  metadata and broadens public-repo exposure.
- **Local ignored files only:** difficult to restore approved private profiles.
- **Git submodule to a private repo:** makes public setup depend on optional
  private permissions and tightly couples lifecycles.
- **Automatic private repository discovery:** violates explicit consent and
  work/personal boundaries.

## Consequences and follow-up

Build an explicit opt-in flow, safe remote verification, non-destructive
fast-forward updates, tested mise load order and per-target conflict handling.
Keep private content out of public Git, GitHub Pages, CI and logs; public
setup must succeed without private credentials.

See [configuration layers](../architecture/private-configuration.md) and
[roadmap](../roadmap.md). Implement later with dummy fixture repositories
rather than accessing real work resources.
