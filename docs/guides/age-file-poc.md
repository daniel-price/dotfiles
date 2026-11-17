# POC 1B: age-encrypted file history

**Status:** Experimental; synthetic files only. Not part of bootstrap, and no origin or watcher is configured.

Question: Can mise encrypt a whole file from its **first** Git checkpoint, preserve two versions without plaintext in any reachable Git blob, reject recovery without an age identity, and restore a previous version with the identity? This tests mise's built-in tracked-file history, **not** a custom encryption or Git manager.

## Run

Prerequisites: `git` and `mise` with `mise dot track --encrypt` support. If `age-keygen` is missing, the script reuses POC 1A's reviewed manifest to offer a **separately approved** installation of pinned `age@1.3.2` through mise. Declining leaves no demo workspace; an approved tool install uses mise's normal per-user tool storage.

Review the script first:

```sh
bash scripts/poc/age-file.sh
bash scripts/poc/age-file.sh --apply
```

The default is read-only. `--apply` requires a terminal and explicit approval. It creates a new disposable directory under `${TMPDIR:-/tmp}`, with isolated HOME, XDG paths and mise config/data/state/cache. It generates a **disposable age identity** outside the history store, writes fake versions of `example.conf`, tracks the file with `--encrypt` *before* its first save, and checks every reachable Git blob for either plaintext version. It then verifies a missing-key rollback fails without modifying the live file and a keyed rollback restores version one.

The script prints the workspace and history paths but never the identity or decrypted contents. It does not configure a remote, launch a watcher, touch your real dotfiles checkout, or run bootstrap. A second accepted run creates a different workspace. Declining creates nothing.

## Independent fresh-machine recovery check

The script's rollback exercises local decryption but is **not** a second-machine test. To validate that separately, use two disposable homes or an isolated test machine, **never** your actual home:

1. Complete `--apply`. Note the printed workspace. The history is at `home/.local/state/mise/history/repo.git`; the identity is `identity.txt`. Do **not** put the identity into history.
2. Create a second disposable home with fresh XDG paths and a new mise global configuration. Give it the same public recipient under `[history.encryption]`, and configure `[dotfiles]` for its own `~/.config/poc/example.conf` with `{ mode = "track", encrypt = true }`. Set `[settings.history]` `sync = "manual"`.
3. Transfer only the history Git repository into the second home's `$MISE_STATE_DIR/history/repo.git`. Do not copy the first home's configuration, private identity, or plaintext file. Verify `git --git-dir="$MISE_STATE_DIR/history/repo.git" log --all` succeeds.
4. **Without the key**, attempt `mise dot rollback "$HOME/.config/poc/example.conf" --to latest --dry-run` then the real rollback if the preview indicates a write. It must refuse to decrypt; the target must not be populated. If a particular mise version does not support a missing live file with rollback, use `mise dot history` and document that limitation rather than bypassing encryption or changing the real HOME.
5. Securely copy the synthetic `identity.txt` outside any tracked path, set mode `600`, set `MISE_AGE_KEY_FILE` to its path, and retry the preview and rollback. The restored file should equal the latest saved synthetic version. Check that the file is plaintext **on disk**, while every Git blob remains ciphertext. A compatible `mise bootstrap --adopt` using an explicitly configured disposable local origin is an alternative for validating full machine adoption.
6. Remove the disposable homes and identity after recording the outcome. Never publish this history or use real credentials.

For a stricter transport test, use a **local bare Git origin**, configure it manually, and exchange history between the two isolated homes. Do not use a real private or public remote for this experiment.

## Manual acceptance checks

- Preview and decline change nothing. Noninteractive `--apply` refuses.
- With permission, the script reports both PASS lines; a second run uses a fresh workspace.
- `git --git-dir="<printed-history>" rev-list --all` includes multiple commits. Inspect commits and blobs, not merely the HEAD worktree.
- The history repository contains ciphertext, but the tracked live file is plaintext and mode-restricted.
- A missing identity refuses to restore; a matching identity restores the expected older version.
- Repeat on Pop!_OS and macOS where available; record mise version and any CLI differences.
- No Git remote is configured; no change appears in the public dotfiles checkout.

**Important:** Encrypting a previously tracked file cannot remove plaintext from older Git history. Mise's encryption protects saved file *contents*, not file names, public metadata, plaintext live files, identities, or secrets exposed to running processes. A private origin alone does not replace encryption. The script is deliberately not wired into machine setup until the fresh-machine restore has been manually verified.

References: [mise encrypted files](https://mise.jdx.dev/dotfiles/encryption.html), [dotfiles history](https://mise.jdx.dev/dotfiles/history.html), [sync and adoption](https://mise.jdx.dev/dotfiles/sync.html).
