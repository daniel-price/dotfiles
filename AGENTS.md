# Agent instructions

The [documentation home](docs/index.md) is the primary reference; read
[requirements](docs/requirements.md), [architecture](docs/architecture/index.md)
and [roadmap](docs/roadmap.md) for the part being changed. Detailed former
plans and architectural discussion belong in [reference & history](docs/reference/index.md),
and are **not** evidence that a feature already exists.

- **Scope:** operate only on this personal dotfiles repository and other
  resources explicitly authorised for the task. Do not inspect or interact
  with unrelated repositories, organisations or employer resources.
- **Private/work boundaries:** the public setup must remain standalone. A
  private configuration repository is an optional, separately authorised
  source; do not discover, read, clone or modify it without explicit permission.
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
  Git-backed tracked-file history. An optional private configuration repo is
  distinct from both of those; its composition/precedence is not implemented.
- **PRs:** small changes; list commands actually executed, untested platforms,
  and a numbered, copyable manual test plan with expected results and safe
  cleanup. Update human-facing docs whenever behaviour changes.
- **CI:** workflow run steps call versioned scripts, with tool commands and
  flags owned by those scripts. Reuse the same scripts from local commands and
  Git hooks. Actions may handle runtime setup, caches, artifacts and deployment.
- **Tests:** verify meaningful behaviour and real regression risks. Avoid
  redundant assertions or checks tied only to historical implementation details.
- **Layout:** `scripts/setup/` is for machine setup, `scripts/dev/` is for
  maintaining this checkout, and `scripts/lib/` provides internal shared helpers.
  Put eventual everyday shell commands in `bin/` only when they exist. `.config/`
  holds intended user dotfiles. Keep `bin/,bootstrap` as the sole bootstrap
  implementation and entry documentation/tool configuration at the root.
- **Cleanup:** default to dry-run; remove only explicitly eligible targets after terminal confirmation. Never use `mise implode`, system package prune, forceful dotfile removal or automatic deletion of private overlays. Tool installations can be shared across projects.
- **Docs:** user-facing guidance should be accurate, concise and task-oriented.
  Store dense plans and older investigations under `docs/reference/`, label
  historical material, and link to it instead of duplicating it.

Do not claim a test or deployment succeeded unless it was actually run and
verified. In particular, GitHub Pages is not live merely because its workflow
exists.
