# ADR-0005: Use argc annotations for standalone Bash CLI parsing

**Status:** Accepted
**Date:** 2026-11-22

## Context

Small personal Bash utilities need flags, options, validation, help, Zsh completion and generated reference docs without maintaining multiple argument definitions or compiling after each edit. The [argc experiment (PR #61)](https://github.com/daniel-price/dotfiles/pull/61) tested annotation parsing and JSON-to-Markdown generation; [Usage (PR #60)](https://github.com/daniel-price/dotfiles/pull/60), custom libraries (PR #62), and getoptions/Argsh (PR #63) were alternatives.

## Decision

- Prefer [argc](https://github.com/sigoden/argc) for **standalone Bash commands** where argument parsing and completion justify it. Keep lightweight scripts unchanged unless there is a clear benefit. This PR converts `,uuid` as the first production example.
- Pin argc 1.24.0 in the machine and development mise manifests. Machine bootstrap continues to require only its existing minimal prerequisites and offers argc installation explicitly. No additional compilation/build step is required after editing a command.
- Generate Markdown at documentation-build time from `argc --argc-export` metadata via `dev/generators/argc_docs.py`. Never parse the annotations twice. Add reviewed command paths to its allowlist as they are migrated.
- Register argc-generated Zsh completion only when argc is available. Keep shell-state-changing functions (for example `cdWorktree`) native to Zsh.
- Retain the existing `--help` reference for commands that have not migrated, without broad changes to bootstrap/setup utilities.

## Consequences and limitations

Argc is a runtime dependency for migrated utilities, installed with explicit consent. The Markdown converter depends on the pinned argc JSON schema and is validated by tests and the strict documentation build. Interactive completion behaviour, including suggestions before and after `--`, should be smoke-tested locally; it is not claimed as verified merely because a completion script generates. The repo can adopt argc incrementally rather than migrating all commands at once.

## Alternatives

**Usage** generates Markdown natively but has more verbose declarations. **getoptions** and a custom library require additional completion/docs adapters. **Standalone argc builds** remove the runtime dependency but introduce a save-to-build step, which is not desirable for these managed machines.
