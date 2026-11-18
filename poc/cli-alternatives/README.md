# Declarative CLI alternatives: getoptions vs Argsh

**POC only.** No changes to production `bin/`, Zsh startup, `mise.toml`, bootstrap, or deployed docs.

## Comparison

| Candidate | Native parsing | Single declaration | Markdown | Zsh completion | Bash 3.2 | Runtime dependency |
| --- | --- | --- | --- | --- | --- | --- |
| getoptions v3.3.2 | Yes (DSL) | Yes (DSL plus a positional marker) | Tiny adapter reads DSL | Tiny adapter and generic Zsh bridge | Intended yes, CI checks | One vendored CC0 parser library, no binary |
| Argsh pinned commit | Yes (`:args`) | Yes for flags/positionals | Advertised via `:usage docgen` but test required | Advertised via `:usage completion`; test required | No: associative arrays, `local -n` | Pinned Bash runtime; optional native Rust builtin may be required for advertised tooling |

**Caveat:** Argsh's `:args`-only single-command interface is not the same as its `:usage`-based subcommand interface. The `usage-probe` explicitly tests advertised tooling. If it returns an unknown-command error without native builtins, this is a real shortcoming, not a passing test.

## Test

From the repository root:

```bash
bash poc/cli-alternatives/getoptions/check.sh   # offline, portable
bash poc/cli-alternatives/check.sh --install      # includes pinned Argsh download and capability probes
```

The Argsh test runner downloads only `argsh.min.sh` from upstream commit `2b83318b6d1a842ba8db59cad446564335502091` into a temporary directory, checks Git blob SHA `0d56efa1bc3a1906dd4f087f2aa668fd3d52974e`, and removes the download when done. No global install.

The getoptions parser library is copied from `ko1nksm/getoptions` commit `139d121807db67f632b412b2a00ece851df73203` (v3.3.2); it is **CC0-1.0**. Argsh source is **MIT**.

## Try getoptions manually

```bash
bash poc/cli-alternatives/getoptions/case-text --case upper "Hello World"
bash poc/cli-alternatives/getoptions/case-text --case invalid hello
bash poc/cli-alternatives/getoptions/case-text --help
bash poc/cli-alternatives/getoptions/case-text --_poc_markdown > /tmp/getoptions-case-text.md
```

The generic completion layer introspects `parser_definition` directly on each invocation, so **editing a declaration changes completion immediately without regenerating scripts**. The vendored getoptions parser library is sourced at runtime.

### Test Zsh in a fresh interactive shell

Run from a checked-out PR branch, in Zsh:

```zsh
autoload -Uz compinit; compinit
export CLI_POC_GETOPTIONS_CASE="$PWD/poc/cli-alternatives/getoptions/case-text"
export CLI_POC_GETOPTIONS_JUMP="$PWD/poc/cli-alternatives/getoptions/jump-resolve"
mkdir -p /tmp/dotfiles-cli-alt-demo
export CLI_POC_DEMO_ROOT=/tmp/dotfiles-cli-alt-demo
fpath=("$PWD/poc/cli-alternatives/completion" $fpath)
autoload -Uz _poc_getoptions
compdef _poc_getoptions ,case-text ,jump-demo
,case-text() { bash "$CLI_POC_GETOPTIONS_CASE" "$@"; }
source poc/cli-alternatives/getoptions/zsh-jump-demo.zsh
```

Test real Tab in Zsh (the `<TAB>` notation means press the Tab key):

```text
,case-text <TAB>
,case-text --<TAB>
,case-text --case <TAB>
,case-text --case=<TAB>
,jump-demo <TAB>
```

Then run `,jump-demo demo`, and `pwd`; verify it changed the *current* Zsh process. Completing paths requires native Zsh `_files` and the bridge's generic `_poc_getoptions` function.

**Interactive bare-Tab success is unverified unless a genuine PTY/in-person test passes.** Generating a completion file or candidate list does not prove this behaviour.

## Why these aren't automatically winners

**getoptions:** robust POSIX option parsing, no build, but this POC needs roughly 100 lines of shared metadata/completion/Markdown glue. The generic Zsh bridge also needs registration once per command. That custom infrastructure creates maintenance costs for a personal dotfiles repo. Positional validation is a small explicit check after parse; the `poc_arg` marker is metadata only.

**Argsh:** elegant Bash array syntax and optional rich tooling; however Bash 3.2 is unsupported, and its documentation/completion commands must be tested against the *actual pinned pure-Bash runtime*, not assumed from examples that may depend on a loadable Rust builtin. A `:usage` subcommand tree is also heavier than an individual single-command utility.

## Scope and test evidence

The getoptions check tests defaults, flags, `--flag=value`, positional, `--`, invalid values, missing inputs, Markdown, completion candidates, and bookmark resolution. Argsh tests equivalent parsing/validation and prints explicit capability-probe results for `completion zsh`, `docgen md`, and `docgen man`.

CI runs Bash tests on Ubuntu and macOS; an additional interactive PTY test is needed to assert bare-Tab and description-menu behaviour. No claimed CI passes until the checks finish.
