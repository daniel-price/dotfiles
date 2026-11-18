# Usage inline-annotation POC

Experimental only. This does **not** change `bin/`, Zsh startup, bootstrap, or production CLI behavior.

This deliberately uses the same synthetic `,case-text` CLI as the [argc POC](../cli-argc/README.md):

```text
,case-text [--case lower|upper] [-n|--no-newline] <text>
```

It converts text using `tr`; there are no writes or external service calls. The command interface is declared in the script using `#USAGE` comments. Parsing, required-argument/choice validation and `--help` come from the `usage` shebang.

## Run on macOS or Ubuntu/Pop!_OS

Prerequisite: `mise` already installed. Only install the explicitly pinned tool for this isolated POC:

```sh
mise -C poc/cli-usage install
bash poc/cli-usage/check.sh
```

Equivalent one-off explicit install-and-check: `bash poc/cli-usage/check.sh --install`.

```sh
mise -C poc/cli-usage exec -- ./bin/,case-text --help
mise -C poc/cli-usage exec -- ./bin/,case-text --case upper "Hello World"
mise -C poc/cli-usage exec -- ./bin/,case-text --case invalid hello
```

`check.sh` verifies help, output, invalid choices, missing arguments, unknown flags, generated Markdown and Zsh completion. The POC tool is pinned to Usage 7.4.0 in its own `mise.toml`, leaving the root tool configuration unchanged.

## Completion and docs

Inside `mise -C poc/cli-usage exec -- bash`, from `poc/cli-usage`:

```sh
usage generate markdown --file ./bin/,case-text
usage generate completion zsh ,case-text --file ./bin/,case-text
usage generate completion-init zsh
```

The completion output is generated from the inline declaration, but Usage must remain installed for interactive completion and for running the script. Nothing is automatically added to `.zshrc`.

## Comparison questions

- Are KDL-style annotations easy to understand and maintain inside a shell script?
- Is a runtime dependency on Usage acceptable for everyday commands and bootstrap?
- Does generated Markdown and Zsh completion remove enough custom tooling?
- For shell-state-changing `,wt`, the parser still cannot perform `cd` on behalf of the calling shell; a native Zsh function would be required.

Cleanup: remove the optional POC tool only if you intentionally want to (`mise uninstall usage@7.4.0`); no shell config or production command is changed.
