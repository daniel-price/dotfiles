# POC 1A: age-encrypted environment values

**Status:** Experimental; synthetic values only. Not wired into bootstrap or machine setup.

Question: can a committed, encrypted mise environment value be restored using an identity held **outside Git**, while failing closed without the key? This uses mise's [experimental age values](https://mise.jdx.dev/environments/secrets/age.html); it does not introduce a secrets framework.

## Run

Prerequisite: `mise` with age-value support. The POC uses an existing `age-keygen` if available; otherwise it offers to install pinned `age@1.3.2` through a dedicated [mise tool manifest](../../scripts/poc/age-tools.toml). Review the script and manifest first. This tool is **not** part of normal bootstrap.

```sh
bash scripts/poc/age-env.sh
bash scripts/poc/age-env.sh --apply
```

The default command previews only. `--apply` first asks whether to run the experiment, then separately requests consent to install the pinned `age` tool if it is missing. Declining either makes no changes. On approval it creates a fresh directory under `${TMPDIR:-/tmp}` with `mise.toml` and an **untracked, synthetic-only** `identity.txt`. It tests that `mise exec` receives the fake value and that decryption fails with a missing key. No files in your dotfiles checkout are changed. If the `age` installation is approved, mise stores the tool in its normal per-user installation directory; it does not modify your global tool selection. The script prints the workspace path, not the key or decrypted value.

## Verify recovery on a second machine / clean environment

1. After `--apply`, find the printed workspace path. Confirm `mise.toml` contains `POC_TOKEN = { age = "..." }`, **not** `synthetic-demo-only`. Do not publish `identity.txt`.
2. Copy **only** the encrypted `mise.toml` to another temporary directory (or a test machine). With no matching identity, run `MISE_AGE_KEY_FILE=/path/to/missing mise -C /path/to/new-directory exec -- sh -c 'test -n "$POC_TOKEN"'`. It must fail.
3. Transfer `identity.txt` to the test machine via a separately secured channel (never via this public Git repo). Set file permissions to `600`. Then run `MISE_AGE_KEY_FILE=/secure/path/identity.txt mise -C /path/to/new-directory exec -- sh -c 'test "$POC_TOKEN" = synthetic-demo-only'`. It must succeed without printing the value.
4. To test first-commit/history hygiene, initialise a **new disposable Git repository** containing only the encrypted `mise.toml` (not the identity), commit it, then examine `git log -p --all` and `git grep synthetic-demo-only $(git rev-list --all)`. No plaintext value or identity should appear in any commit. Delete the temporary Git repository afterwards.
5. Run the script again and decline: no new directory should be created. Accept a second time: it should create a **different** directory rather than overwrite the original.

**Cleanup:** delete the printed temporary POC directories after testing. Their identities are intentionally disposable. Do not use these identities for real secrets.

## Boundaries

- The age identity is the decryption authority. Losing it makes encrypted values unrecoverable; backing up a real identity securely is a separate roadmap POC.
- Decrypted environment values can be observed by the process and through commands such as `mise env`; redaction is not a confidentiality boundary against the process owner.
- No real tokens, personal credentials, work-owned secrets or private repositories may be used for this experiment.
- This demonstrates **single-value** encryption only; encrypted whole files and history remain **POC 1B**.
- No default shell activation or automatic secret injection is added.

Reference: [mise age values](https://mise.jdx.dev/environments/secrets/age.html).
