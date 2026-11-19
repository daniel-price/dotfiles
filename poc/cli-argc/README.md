# argc inline-annotation POC

Experimental only. This does **not** change `bin/`, Zsh startup, bootstrap, or production CLI behavior.

This deliberately uses the same synthetic `,case-text` CLI as the [Usage POC](../cli-usage/README.md):

```text
,case-text [--case lower|upper] [-n|--no-newline] <text>
```

It converts text using `tr`; there are no writes or external service calls. The interface lives in the script as `# @option`, `# @flag` and `# @arg` annotations. The `eval "$(argc --argc-eval "$0" "$@")"` line delegates parsing, validation and help to argc.

## Run on macOS or Ubuntu/Pop!_OS

Prerequisite: `mise` already installed. Only install the explicitly pinned tool for this isolated POC:

```sh
mise -C poc/cli-argc install
bash poc/cli-argc/check.sh
```

Equivalent one-off explicit install-and-check: `bash poc/cli-argc/check.sh --install`.

```sh
mise -C poc/cli-argc exec -- ./bin/,case-text --help
mise -C poc/cli-argc exec -- ./bin/,case-text --case upper "Hello World"
mise -C poc/cli-argc exec -- ./bin/,case-text --case invalid hello
```

`check.sh` verifies help, output, invalid choices, missing arguments, unknown flags, generated Markdown from argc's JSON export, man pages and Zsh completion. It also builds a standalone Bash script with `argc --argc-build` and runs it without argc on `PATH`. The POC tool is pinned to argc 1.24.0 in its own `mise.toml`.

## Completion and docs

Inside `mise -C poc/cli-argc exec -- bash`, from `poc/cli-argc`:

```sh
argc --argc-completions zsh ,case-text
argc --argc-mangen ./bin/,case-text /tmp/argc-poc-man
argc --argc-export ./bin/,case-text | python3 export_to_markdown.py > /tmp/argc-reference.md
argc --argc-build ./bin/,case-text /tmp/argc-poc-built
```

The generated Zsh completion calls argc at completion time. Argc generates man pages directly, and `--argc-export` exposes a structured JSON definition. The small `export_to_markdown.py` converts that export to Markdown without reading or parsing shell comments. Run it in a Zensical docs-build step; editing a command does not require rebuilding its executable. Python 3 is needed only for documentation generation, not command execution. The generated output includes option names, descriptions, required status, defaults, choices, positional arguments and subcommands. This POC currently covers those core fields rather than every advanced argc annotation. The standalone built script does not require argc to run. No shell configuration is modified.

## Comparison questions

- Are Bash-style `# @...` annotations more approachable than KDL-style `#USAGE`?
- Is the `eval` call and generated shell code acceptable in custom scripts?
- Is building standalone scripts worth the additional build step?
- Would generated man pages or exported metadata be sufficient for documentation?
- For shell-state-changing `,wt`, an external argc invocation still cannot `cd` on behalf of a parent Zsh shell.

Cleanup: remove the optional POC tool only if you intentionally want to (`mise uninstall argc@1.24.0`); no shell config or production command is changed.

## Decision record

See [ADR.md](ADR.md) for the provisional architecture decision and trade-offs. Keep this branch in draft; no production CLI or bootstrap migration is part of this POC. Interactive bare-Tab completion is still unverified and is no longer treated as an adoption blocker.
