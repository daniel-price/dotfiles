# Add or change a tool

Machine tools now have **one version source**:
`scripts/setup/mise.toml`. It declares Neovim `0.12.6` and Zellij
`0.46.0`, independently of the root `mise.toml`, which is only for
developing this checkout.

1. Add or change a pinned version under `[tools]` in
   `scripts/setup/mise.toml`. Review its source and release.
2. If it is a system package instead, add a platform-specific
   `[bootstrap.packages]` declaration in the same file.
3. For a new version-managed tool, extend the reviewed name list in
   `scripts/setup/bootstrap.sh` so each installation has its own explicit
   approval. The *version* must not be duplicated in Bash.
4. Check `mise install --dry-run-code` in an isolated machine-config
   context. Verify decline, already-installed, repeat and version-change
   behaviour before relying on it on your machine.
5. Update the [tool inventory](../architecture/platforms.md#installed-tool-inventory).

Only `scripts/setup/bootstrap.sh` runs machine provisioning. Existing
software is not automatically upgraded. Development tools are installed
separately by `scripts/dev/install-dev-tools.sh`.
