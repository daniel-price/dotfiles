# ADR-0002: Publish a human-first handbook from the repository

**Status:** Accepted as the documentation design; deployment pending  
**Date:** 2026-11-15

## Context

The repository needs to explain how to build, use and recover the development
environment. Dense plans help future maintainers and coding agents, but bury
the most useful information when mixed into the main documentation.

## Decision

Keep Markdown under `docs/` as the canonical source. Use **Zensical** to
build a static GitHub Pages site, hosted on this repository's Pages project
path. Keep `README.md` and `AGENTS.md` short entry points that link to
the same explanations. CI builds the site for PRs; only the main branch deploys.

Use task-focused pages for everyday operations and put ADRs, deep implementation
plans and historical investigation under **Reference & history**. Label
material as planned, implemented, proposed or historical as appropriate.

## Alternatives considered

- **README-only:** easy to start, difficult to navigate as the setup grows.
- **Custom Astro site:** flexible but unnecessary application maintenance.
- **MkDocs/other generators:** also reasonable; Zensical offers simple
  Markdown configuration and built-in navigation/search.

## Consequences

Docs are versioned and reviewable alongside code, with no separate CMS.
Pages must be enabled with **GitHub Actions** as the publishing source.
Publishing a document exposes it publicly regardless of whether it appears in
the navigation. Only the README and site index should introduce the project;
do not copy sections into agent files or ADRs.
