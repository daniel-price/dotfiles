# Agent instructions

The [documentation home](docs/index.md) is the primary reference; read
[requirements](docs/requirements.md), [architecture](docs/architecture/index.md)
and [roadmap](docs/roadmap.md) for the part being changed. Detailed former
plans and architectural discussion belong in [reference & history](docs/reference/index.md),
and are **not** evidence that a feature already exists.

- **Scope:** operate only on this personal dotfiles repository and other
  resources explicitly authorised for the task. Do not inspect or interact
  with unrelated repositories, organisations or employer resources.
- **Base / Profiles:** Base is this standalone public checkout. Profiles are
  optional reusable Git repositories selected explicitly; visibility (private
  or public) is not part of their type. Do not discover, read, clone or modify
  a Profile without explicit authorisation. Local is deferred.
  Work material must remain in an employer-approved location, never in this
  public repository, its documentation, CI logs or generated Pages output.
- **Safety:** this repository is public. Never commit plaintext secrets,
  private age keys, SSH private keys, tokens or real test credentials.
  Synthetic examples only. Never expose private values in CI logs.
- **Behaviour:** read existing files first. Preserve idempotency, per-operation
  interactive confirmation (default no), explicit conflict handling and separate
  software upgrade consent. No silent trust, updates or configuration replacement.
- **OS scope:** macOS and Pop!_OS/Ubuntu-derived Linux; Bash must work with
  macOS's system Bash 3.2. Use apt on Linux and Homebrew on macOS only.
- **Tools:** mise + age is the planned approach, **not yet implemented** for
  dotfiles or encryption. Consult and verify the selected mise version before
  adding commands; distinguish normal Git source from mise's separate
  Git-backed tracked-file history. Profiles are distinct from both; the opt-in Profile feature implements a
  narrow, explicit subset with no automatic Git update or bootstrap integration.
- **PRs:** small changes; list commands actually executed, untested platforms,
  and a numbered, copyable manual test plan with expected results and safe
  cleanup. Update human-facing docs whenever behaviour changes.
- **CI:** workflow run steps call versioned scripts, with tool commands and
  flags owned by those scripts. Reuse the same scripts from local commands and
  Git hooks. Actions may handle runtime setup, caches, artifacts and deployment.
- **Tests:** verify meaningful behaviour and real regression risks. Avoid
  redundant assertions or checks tied only to historical implementation details.
- **Bash entrypoints:** start executable Bash scripts with `#!/usr/bin/env bash`,
  `set -euo pipefail`, and the same script-based Git checkout root discovery:
  `ROOT=$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)`.
  Source dependencies by `$ROOT` (retain ShellCheck annotations), then declare
  `main() { ...; }` and invoke `main "$@"` for ordinary scripts. For
  argc-based CLIs, `argc --argc-eval` invokes `main` itself: do not call it twice.
  This deliberately requires Git
  and a checkout; never infer the root from the caller's current directory.
  The self-snapshotting updater must instead honour its injected snapshot root.
  Sourced Bash libraries must not set shell options, discover the checkout,
  or invoke `main`. Commands such as `,wt` may independently discover a
  *target project's* Git root when that is their purpose.
- **Bash errors:** use `set -euo pipefail` for unhandled failures; do not
  install generic `ERR` traps or use a shared line-number-based reporter.
  Add contextual `|| die "Action failed ..."` messages for important operations,
  particularly writes and user-approved changes. Preserve failure exit status
  where callers depend on it, and avoid masking failures during cleanup.
- **Layout:** `setup/` is for machine setup, `dev/scripts/` is for
  maintaining this checkout, and `lib/` provides internal shared helpers.
  Put eventual everyday shell commands in `bin/` only when they exist. `.config/`
  holds intended user dotfiles. Keep `bin/,bootstrap` as the sole bootstrap
  implementation and entry documentation/tool configuration at the root.
- **Cleanup:** default to dry-run; remove only explicitly eligible targets after terminal confirmation. Never use `mise implode`, system package prune, forceful dotfile removal or automatic deletion of selected Profile configurations. Tool installations can be shared across projects.
- **Docs:** user-facing guidance should be accurate, concise and task-oriented.
  Keep guides command-first: prerequisites, commands and essential caveats only.
  Do not repeat safeguards, inventories or implementation details. Store dense
  plans and older investigations under `docs/reference/` and label historical material.

Do not claim a test or deployment succeeded unless it was actually run and
verified. In particular, GitHub Pages is not live merely because its workflow
exists.
