# Add or change a tool

Machine tools are pinned in [`scripts/setup/mise.toml`](../../scripts/setup/mise.toml), separate from the root `mise.toml` used for repository development.

1. Add or change an exact version under `[tools]`. Use `[bootstrap.packages]` for OS packages.
2. Review the source/version and run `bash scripts/setup/bootstrap.sh`. It previews missing components and asks before installing.
3. Test an already-installed tool, refusal and repeat run before merging.

Bootstrap discovers declared tools from the manifest; **do not duplicate their versions or names in Bash**. Upgrading an existing tool is separate from installing missing tools.

See [platforms](../architecture/platforms.md) and [roadmap](../roadmap.md).
