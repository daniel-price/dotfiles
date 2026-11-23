# Add or change a tool

Base machine tools are pinned in [`.config/mise/base-tools.toml`](../../.config/mise/base-tools.toml), included by both [bootstrap](../../scripts/setup/mise.toml) and [global mise config](../../.config/mise/config.toml). The root `mise.toml` remains for repository development.

1. Add or change a Base version under `[tools]` in `.config/mise/base-tools.toml`; for optional tools create a `config.<env>.toml` module instead. Use `[bootstrap.packages]` in `scripts/setup/mise.toml` for Base OS packages (for example, `apt:wl-clipboard` on Linux).
2. Review the source/version and run `bash bin/,bootstrap --no-update`. It previews missing components and asks before installing.
3. Test an already-installed tool, refusal and repeat run before merging.

Bootstrap discovers declared tools from the manifest; **do not duplicate their versions or names in Bash**. Upgrading an existing tool is separate from installing missing tools.

GitHub CLI (`gh`) is installed from the pinned machine manifest after approval. Check it with `gh --version`, then authenticate explicitly with `gh auth login`. Credentials are managed by GitHub CLI, not this public repository.

See [platforms](../architecture/platforms.md) and [roadmap](../roadmap.md).
