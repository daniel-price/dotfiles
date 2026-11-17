# OpenCode CLI: installation and execution boundaries

OpenCode is a **coding agent**, not merely a passive command-line utility.
It can inspect files, modify code and run shell commands. Installing its CLI
does **not** isolate those operations from the host.

## Install and verify

The reviewed machine manifest pins `opencode = "2.3.0"` using mise's
`opencode` registry entry (OpenCode 2 from `@opencode/cli`).
The current reviewed mise bootstrap requires mise 2026.11.9 or later,
which supports the OpenCode 2 registry entry.

From the dotfiles checkout:

```sh
bash scripts/setup/bootstrap.sh
```

Bootstrap asks **separately** before installing a missing
`opencode@2.3.0`; decline if this host should not run an agent.
The OpenCode npm package uses a postinstall script to select the native
binary. A version pin makes updates explicit but does not eliminate the
supply-chain risk of running third-party installation code.

After accepting, start a new configured Zsh session and check:

```sh
opencode --version
```

Expect `2.3.0`. Alternatively, without depending on shell activation,
run from the dotfiles checkout root:

```sh
MISE_GLOBAL_CONFIG_FILE="$PWD/scripts/setup/mise.toml" \
  mise -C / exec opencode@2.3.0 -- opencode --version
```

Run `opencode` **from the individual project directory**, rather than
your home directory or a directory containing multiple unrelated projects.
Authenticate with your intended model provider through OpenCode's own
setup; do not commit API keys, tokens, credentials or generated session
data to this public dotfiles repository.

## Choose the correct execution boundary

| Situation | Approach |
| --- | --- |
| Trusted personal repository, interactive review | Pinned local CLI via mise with conservative tool permissions |
| Unknown project, untrusted dependencies or autonomous agents | Separate VM or purpose-built agent sandbox with only the intended workspace exposed |
| Long-running services, e.g. media servers | A separately managed service/container, not this machine CLI manifest |

**A native OpenCode process has the same filesystem, process, network and
credential authority as the signed-in user.** OpenCode's default V2 permission
policy largely allows shell commands and access outside the project. Prompt
instructions or an `AGENTS.md` file are not access controls.

For a more conservative **optional** per-user configuration, review and
create `~/.config/opencode/opencode.jsonc` yourself (do not overwrite
existing settings):

```json
{
  "$schema": "https://opencode.ai/config.json",
  "update": "notify",
  "permissions": [
    { "action": "external_directory", "resource": "*", "effect": "deny" },
    { "action": "shell", "resource": "*", "effect": "ask" },
    { "action": "shell", "resource": "git status *", "effect": "allow" },
    { "action": "shell", "resource": "git diff *", "effect": "allow" },
    { "action": "shell", "resource": "git push *", "effect": "deny" }
  ]
}
```

These are OpenCode **2** rule names. They do **not** form an OS security
sandbox; shell command analysis and directory inference are best-effort.
Project-level and agent-specific rules can change effective permissions.
Keep sensitive directories and credentials outside the agent's reach,
review its proposed actions, and do not grant blanket shell approvals.
Do not run an unisolated agent against employer code or credentials
unless that use is expressly approved and appropriately controlled.

These settings are **documentation only**: bootstrap does not create,
replace or link `~/.config/opencode/opencode.jsonc`. A separate,
conflict-safe opt-in deployment would be needed to manage that file.

## What about Docker?

For straightforward interactive work in trusted repositories, running
the CLI locally keeps access to your normal git, language toolchains
and terminal simple. Plain `docker run` is **not equivalent to a
secure agent sandbox**, especially if the host home directory, git/SSH
credentials or the Docker socket are mounted into it.

Docker publishes a purpose-built OpenCode sandbox workflow
(`sbx run opencode`), but **Docker currently does not test or support
Docker Sandboxes on Pop!_OS**, and its Linux setup script can configure
the wrong package repository on Ubuntu derivatives. Do not run that
installation script on Pop!_OS as a shortcut. Consider an isolated VM
or another vetted sandbox if you need automated or untrusted execution.

## Cleanup

```sh
bash scripts/setup/cleanup.sh           # Preview only
bash scripts/setup/cleanup.sh --apply   # Individual removal confirmations
```

Cleanup only considers the exact pinned mise tool version. It does
**not** remove OpenCode provider credentials, user-level configuration,
conversation history or other application state. Review those separately
if complete removal is required.

References: [OpenCode installation](https://opencode.ai/docs/),
[OpenCode V2 permissions](https://opencode.ai/docs/permissions/),
[OpenCode configuration](https://opencode.ai/docs/config/),
[mise npm backend](https://mise.jdx.dev/dev-tools/backends/npm),
[Docker's OpenCode sandbox guide](https://docs.docker.com/ai/sandboxes/agents/opencode/),
[Docker's Linux sandbox support note](https://docs.docker.com/ai/sandboxes/install).
