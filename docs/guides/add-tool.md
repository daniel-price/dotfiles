# Add or change a tool

Machine tools are pinned in [`scripts/setup/mise.toml`](../../scripts/setup/mise.toml), separate from the root `mise.toml` used for repository development.

1. Add or change an exact version under `[tools]`. Use `[bootstrap.packages]` for OS packages.
2. Review the source/version and run `bash bin/,bootstrap --no-update`. It previews missing components and asks before installing.
3. Test an already-installed tool, refusal and repeat run before merging.

Bootstrap discovers declared tools from the manifest; **do not duplicate their versions or names in Bash**. Upgrading an existing tool is separate from installing missing tools.

GitHub CLI (`gh`) is installed from the pinned machine manifest after approval. Check it with `gh --version`, then authenticate explicitly with `gh auth login`. Credentials are managed by GitHub CLI, not this public repository.

See [platforms](../architecture/platforms.md) and [roadmap](../roadmap.md).
