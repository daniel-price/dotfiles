# Requirements and principles

These are requirements of the system, **independent of whichever tools implement
them**. Implementation decisions belong in [Architecture](architecture/index.md).

| Requirement | Meaning |
| --- | --- |
| Cross-platform | A shared Base on Pop!_OS and macOS; platform-specific behaviour only where necessary. |
| Public by default | Source and documentation can be viewed publicly; never expose plaintext secrets or decryption identities. |
| Base + Profiles | Base works independently; selected reusable Profiles are optional, authorised and checked for conflicts. |
| Standalone Base | Bootstrap must work without any Profile checkout or credentials. |
| Work isolation | Use employer-approved storage and devices for work-related files, never assume personal private Git is authorised. |
| Safe and explicit | Inspect first; explain and ask before **each** modifying operation; refusal is safe and defaults to no. |
| Idempotent | Repeating setup should skip already-correct state, not create drift. |
| Recoverable | A new machine can be reconstructed from documented steps and securely backed-up credentials. |
| Non-destructive | Existing configuration conflicts require an informed decision; no silent overwrites or forced upgrades. |
| Simple bootstrap | Minimise prerequisites and avoid a second unnecessary Git download/clone. |
| Maintainable | Prefer established tools over custom scripts, and keep ownership of each responsibility clear. |
| Human-readable | The site explains current behaviour and everyday operations without requiring historical PR context. |
| Auditable | Changes are reviewable in Git; PRs include explicit manual verification steps. |

## Security boundary

The repository is public. Do not publish private SSH keys, age recovery
identities, personal tokens, service credentials, private paths, or sensitive
machine inventory. **Encrypted** material is permissible only after testing
first-encryption behaviour, key recovery, and a clean Git history.

A separate, access-controlled Git repo can store authorised non-public
configuration **only after explicit opt-in**. Work-related files require
employer-approved storage: a private repo under a personal account is not
sufficient. Private Git is not itself secret encryption. See
[Base and Profiles](architecture/configuration.md).

SSH authentication keys should be generated and stored securely on each device.
A managed **Local** configuration layer is deferred. Individual device settings
can remain manually configured until that capability is justified. Existing
ignored patterns (`local/`, `*.local`, and mise's `config.local.toml`) are **not**
loaded by the Profile mechanism.

## Operational rule

Before changing anything: detect the current state, show the affected files
or commands, request interactive consent for **that** operation, and report
whether it was applied, skipped or failed. A normal update must not also
silently upgrade software.
