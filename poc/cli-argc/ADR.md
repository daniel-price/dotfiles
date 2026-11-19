# ADR: Prefer argc for declarative Bash CLIs (provisional)

- **Status:** Proposed — POC only, not approved for a repository-wide migration
- **Date:** 2026-11-19
- **Scope:** Personal `daniel-price/dotfiles` scripts on macOS and Pop!_OS
- **Related POCs:** [argc PR #61](https://github.com/daniel-price/dotfiles/pull/61), [Usage PR #60](https://github.com/daniel-price/dotfiles/pull/60), [custom PR #62](https://github.com/daniel-price/dotfiles/pull/62), [getoptions/Argsh PR #63](https://github.com/daniel-price/dotfiles/pull/63)

## Context

Small Bash utilities should declare flags, positional arguments, defaults, validation and descriptions **once**. The same source should provide runtime parsing, help, Zsh completion, and Markdown reference docs for Zensical. Updating a script should work immediately, without compiling or regenerating committed artifacts.

The user favours the concise, familiar inline `# @flag` / `# @option` / `# @arg` authoring syntax in **argc** over Usage's more structured `#USAGE` annotations. Authoring experience is a recurring daily cost; documentation formatting can be handled once in a shared build-time tool.

Standalone portability is not a critical constraint because the utilities run on managed personal machines. A dependency installed by bootstrap/mise is acceptable, but **bootstrap itself must remain able to run before that dependency exists**.

## Decision (proposed)

1. **Prefer argc for standalone Bash utilities**, using inline annotations and `argc --argc-eval` at runtime. Pin argc with mise and ultimately install it in bootstrap; do not require a separate build step when a script changes.
2. **Generate Markdown at documentation-build time** from `argc --argc-export <script>` JSON, with a thin converter (`export_to_markdown.py`). Do not parse the annotation comments independently or maintain a second argument grammar. Native argc man-page generation remains available.
3. **Keep shell-state-changing commands native to Zsh**, including commands that change the current working directory (such as `,wt`). An external process cannot `cd` the calling shell; preserve common CLI conventions where helpful, without forcing those functions through the Bash runtime.
4. **Keep the evaluation isolated**. No production scripts, root mise configuration, bootstrap, or Zsh init are changed in this POC. Do not merge any experimental PR as a proxy for a repository-wide migration.

## Why this option

| Consideration | argc | Usage |
| --- | --- | --- |
| Script declaration | Concise Bash-style comments, preferred for frequent editing | More structured `#USAGE` syntax |
| Parse, validate and help | Built in at runtime | Built in at runtime |
| Zsh completion | Supported; specific bare-command Tab UX still needs confirmation | Supported; same bare-Tab uncertainty |
| Markdown docs | Small converter over structured `--argc-export` JSON | Built in |
| Man pages | Built in | Built in |
| Rebuild on script edits | **No**, if argc runtime is installed | No |
| Runtime dependency | argc | Usage |

argc loses native Markdown rendering but avoids the long-term cost of a declaration format the user prefers less. The new JSON-to-Markdown experiment tests whether that compromise is cheap enough.

## Alternatives considered

- **Usage:** Good native docs and low integration effort; remains the fallback if argc export proves incomplete or difficult to maintain.
- **getoptions:** Strong shell portability, but custom documentation and completion adapters introduce more code.
- **Custom Bash/Zsh library:** Excessive framework maintenance for personal dotfiles.
- **Argsh:** Bash 3.2 and export/completion limitations in the tested configuration.
- **argc standalone build:** Useful for distribution, but unnecessarily introduces a build step for scripts on personal machines.

## Risks and follow-up

- The Markdown converter depends on argc's exported JSON shape. **Pin and test that schema**, including descriptions, options, defaults, fixed/dynamic choices, positional arguments and subcommands. Keep its scope deliberately narrow.
- Confirm completion installation in real Zsh, including `--<TAB>` and choice completion. **Bare-command `<TAB>` remains unverified and is no longer a deal-breaker**; do not claim it works until observed.
- Verify runtime `argc` can be found in interactive and non-interactive shell environments on macOS and Pop!_OS.
- Before adopting, finish CI checks and review the Markdown output in Zensical.
- Keep any future bootstrap update dependency-minimal and independent of argc.

## Consequences

**Positive:** Short CLI declarations, one source of truth, no per-edit build, reusable docs generator, and optional native man pages.

**Negative:** argc becomes a runtime dependency for the affected Bash utilities; a small converter needs maintenance when the export schema changes; native Zsh functions use a separate implementation.

This is a **proposed direction**, not a claim that every criterion has already been verified.
