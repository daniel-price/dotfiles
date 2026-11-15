# Manage an encrypted secret

**Status: planned — do not use with a real credential yet.**

1. Decide whether the value is a mise environment value or an entire
   mise-tracked file. These have **different storage mechanisms**.
2. Set up and independently back up an age recovery identity outside Git.
3. Prototype with an explicitly fake token in a disposable environment.
4. Confirm only ciphertext enters Git, including **the first version** and
   all subsequent history; check the history origin before any push.
5. Prove restoration on a second machine and safe failure when the identity
   is missing.
6. Check that neither local output nor CI logs reveal plaintext.
7. Write the verified real workflow here once the implementation PR is merged.

SSH authentication private keys should stay machine-specific. If plaintext was
already published, removing the file from the newest commit is not sufficient:
rotate the secret and review the full history.

See [Secrets architecture](../architecture/secrets.md) and
[ADR-0001](../decisions/0001-mise-age.md).
