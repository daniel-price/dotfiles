# Custom Bash registry + Zsh completion POC

Isolated experiment: no changes to production commands, root toolchain, bootstrap, or Zsh startup. This is deliberately not a full CLI framework.

The standalone Bash example declares its flags, allowed values, default, positional argument and descriptions once in `define_cli`. A small Bash library uses the declarations for parsing, validation, help, Markdown, and completion candidates **at runtime** (no regeneration). The Zsh function uses the same library through a resolver, then performs `builtin cd` in the calling shell.

## Checks

```sh
bash poc/cli-custom/check.sh
bash poc/cli-custom/bin/,case-text --case upper "Hello World"
bash poc/cli-custom/bin/,case-text --case invalid Hello
bash poc/cli-custom/bin/,case-text --_poc_markdown > /tmp/cli-custom-reference.md
```

## Interactive Zsh test (manual; not claimed passing)

Run from the root of a checked-out POC branch in a fresh Zsh shell. The checkout may mark connector-created files non-executable; `chmod` is a one-time local setup step, **not** a regeneration/build step:

```zsh
chmod +x poc/cli-custom/bin/,case-text poc/cli-custom/bin/,jump-demo-resolve
autoload -Uz compinit && compinit
export CLI_POC_CASE_TEXT="$PWD/poc/cli-custom/bin/,case-text"
export CLI_POC_JUMP_RESOLVER="$PWD/poc/cli-custom/bin/,jump-demo-resolve"
mkdir -p /tmp/dotfiles-cli-poc-demo
export CLI_POC_DEMO_ROOT=/tmp/dotfiles-cli-poc-demo
fpath=("$PWD/poc/cli-custom/completion" $fpath)
autoload -Uz _case-text _jump-demo
compdef _case-text ,case-text
compdef _jump-demo ,jump-demo
source poc/cli-custom/zsh-jump-demo.zsh
path=("$PWD/poc/cli-custom/bin" $path)
```

Press Tab (do not type `<TAB>`):

```text
,case-text <TAB>          # Expect flags, including --case
,case-text --<TAB>        # Expect long flags
,case-text --case <TAB>   # Expect lower, upper
,jump-demo <TAB>          # Expect demo bookmark and directories
```

Run `,jump-demo demo` then `pwd` to confirm the **current** Zsh shell changed directory. Edit `define_cli` and repeat Tab to see whether updates propagate without regenerating completion files.

## Known limitations

- **Candidate generation is tested**, but interactive Tab and description display are **unverified**. Do not equate the generated candidate list with working shell completion.
- Bash 3.2 syntax is intended; only Linux Bash 5.2 was exercised locally at authoring time. The macOS workflow is additional validation, not yet confirmed passing.
- Parser handles exactly one required positional; no subcommands, option groups or mutually exclusive flags. No man pages. Inline registry is lightweight but centralized library and completion registration remain necessary.
- Zsh completion uses a small native bridge per command; could be reduced to one reusable generic function in a follow-up.
- No third-party dependencies: Bash, Zsh (completion only), basic `tr` (example utility). The POC source is original local code.

## Assessment

This proves the rough architecture is feasible but **does not yet prove it is worth maintaining** versus Usage, argc, Argsh, or a getoptions adapter. Measure registration boilerplate, completion reliability and Bash 3.2 before selecting it.
