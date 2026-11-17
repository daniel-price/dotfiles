# ADR-0002: Generate configuration references at documentation build time

**Status:** Accepted
**Date:** 2026-11-17

## Context

The Zsh guide repeated alias definitions and configuration comments. The
published handbook needs a concise reference to the current configuration,
not the history of its migration.

## Decision

Generate the Zsh reference from the checked-in Zsh configuration during the
existing documentation build. Extract alias definitions without evaluating Zsh
and publish only explicitly marked `# doc:` annotations for behaviour that
cannot be inferred from declarations. Do not commit the generated Markdown.

Keep implementation comments in source and historical explanations in Git/PR
history, rather than copying them into the public guide. Use the same local
build script in CI and for manual previews.

## Consequences

Alias changes automatically update the reference; published documentation
reflects the configuration used for that build. The generator is intentionally
small and tailored to these files rather than a general shell parser. If the
configuration format changes, update the extractor and its tests together.
