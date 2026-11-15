# Roadmap

A small, readable account of **what works now and what comes next**. Detailed
task acceptance criteria are deliberately kept in
[reference & history](reference/index.md) and future GitHub issues/PRs.

## Current status

**Scaffold only.** The two entry points are read-only, and the documentation
site is proposed in a stacked PR. A checkout does not yet configure a machine.

## Next milestones

| Priority | Work | State |
| --- | --- | --- |
| 1 | Finalise safe bootstrap acquisition and prerequisite checks | Planned |
| 2 | Install mise and provision one tool at a time with confirmation | Planned |
| 3 | Add guarded Git updates and a truthful change report | Planned |
| 4 | Deploy one harmless dotfile via native mise; then migrate configs gradually | Planned |
| 5 | Prototype an optional, approved private configuration overlay with explicit opt-in and precedence/conflict tests | Planned |
| 5 | Prototype age encryption and verified restore with fake credentials | Planned |
| 6 | Select and configure a separate history origin if tracked-file sync is needed | Proposed |
| Later | Per-platform settings and optional service/container definitions | Not designed |

## Delivery conventions

A private-overlay implementation must test public-only setup, denied/unavailable
private access, explicitly selected sources, dirty/diverged checkouts, mise
merge order, overlapping target refusal and public CI/site isolation. It must
use synthetic private fixtures, never actual employer repositories.

Each feature should be a small PR with a copyable manual test plan. Keep
existing configuration safe; verify no-change, refusal, conflict and repeat
runs. A completed feature should change the relevant human-facing documentation
from **planned** to **implemented**.

- [Initial scaffold PR](https://github.com/daniel-price/dotfiles/pull/1)
- [Mise architecture decision PR](https://github.com/daniel-price/dotfiles/pull/2)
- [Detailed original implementation plan](reference/scaffold-roadmap.md) —
  historical/agent-oriented, not the authoritative current checklist
