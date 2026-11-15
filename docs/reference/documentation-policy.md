# Documentation maintenance policy

**Audience:** maintainers and coding agents. This is reference guidance, not a
step-by-step daily-use guide.

## Ownership and lifecycle

- `README.md`: terse GitHub entry point.
- `docs/index.md`: human-facing overview and truthful current status.
- `docs/requirements.md`: stable constraints, independent of tools.
- `docs/architecture/`: current intended design; distinguish implemented
  from planned capabilities.
- `docs/getting-started/` and `docs/guides/`: tested commands and how-tos;
  explicitly mark unimplemented procedures instead of guessing.
- `docs/roadmap.md`: milestones/status, linking to issues and PRs.
- `docs/decisions/`: concise ADRs (Proposed / Accepted / Superseded /
  Rejected), with context, decision, alternatives, consequences and date.
- `docs/reference/`: investigation notes, former plans and agent-heavy
  implementation detail; label material historical.
- `AGENTS.md`: concise constraints and pointers, not duplicated tutorials.

## Update rule

Every behaviour-changing PR should update the relevant human guide and status.
Check links and run a strict documentation build. Keep deep plans as references
with dated status notes; don't silently rewrite old decisions to match new ones.
When a decision changes, add a superseding ADR and link the previous record.

## Public site and repository

All tracked documents and their history are public, even if they do not appear
in navigation. Never include passwords, tokens, SSH/age private keys, private
machine identifiers, work materials or personal inventories.

## Local preview and publication

```sh
python3 -m pip install zensical
zensical serve
zensical build --clean --strict
```

CI validates pull requests. After merge into `main`, a publishing job deploys
to GitHub Pages **only if** the repository's Pages publishing source is
configured for GitHub Actions. A passing build alone doesn't prove the site
is publicly reachable.
