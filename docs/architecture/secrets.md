# Secrets and encryption

**Not implemented. Do not use real credentials for experiments yet.**

The public repository may eventually contain reviewed **age-encrypted values**. Mise also offers encrypted **whole-file tracking**, but those files use a *separate history store*, not this public Git checkout. The two mechanisms need distinct POCs.

| Data | Location |
| --- | --- |
| Public configuration | This repository |
| Approved non-public settings | Explicitly selected private source |
| Encrypted values | Only after testing ciphertext-only history |
| Encrypted tracked files | Separate, explicitly configured history origin |
| age identities and per-machine SSH private keys | Outside Git, with secure recovery backup |

Both POCs must prove first-encryption safety, missing-key failure, restore on a second machine and no plaintext in commits or logs. **A private Git repository is not encryption.** Work-owned content also requires employer-approved storage.

See [the capability roadmap](../roadmap.md) and [the secret-management guide](../guides/manage-secret.md).
