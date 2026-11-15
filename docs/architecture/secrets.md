# Secrets and encryption

The dotfiles repository is **public**. Encrypting secrets at rest in Git is
the intended solution, but the feature has **not been implemented or tested**
in this repository yet.

## What lives where?

| Material | Intended location |
| --- | --- |
| Public config and documentation | This Git repository |
| Reviewed age-encrypted values | Public source only after validation |
| Mise's encrypted tracked-file history | A separately configured Git origin, preferably private |
| age private/recovery identities | Secure backup outside every Git repository |
| Per-machine SSH authentication private keys | Local machine; not shared by default |
| Unencrypted local overrides | Ignored local files, never published |

## Two different mise features

1. **Encrypted environment values** (mise's age integration): config can hold
   encrypted individual values. This has been documented as experimental; test
   the selected mise version and plaintext-handling behaviour first.
2. **Encrypted tracked files** (`mise dot track --encrypt`): encrypted versions
   are placed in mise's **separate tracked-file Git history**, not magically
   inside the normal public dotfiles checkout. Do not assume that making this
   source repository public makes the history store safe to push publicly.

Neither mechanism is currently configured here. Never test with real keys.
Validate first encryption, history inspection, a second-machine restore, a
missing-key failure and the recovery-key backup before enabling a sync process.
If plaintext has already been committed publicly, treat the credential as
compromised and rotate it.

For the design rationale, see [ADR-0001](../decisions/0001-mise-age.md);
for experiments yet to run, see the [historical implementation
plan](../reference/scaffold-roadmap.md).
