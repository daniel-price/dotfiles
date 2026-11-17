# Manage a dotfile

Dotfiles are declared under `[dotfiles]` in [`scripts/setup/mise.toml`](../../scripts/setup/mise.toml). Only the reviewed Zsh target is managed today.

1. Review the source file; remove credentials and machine/work-specific values.
2. Declare one explicit source and target.
3. Preview changes and refuse existing files or unrelated symlinks.
4. Test approval, refusal, idempotence and conflicts in a temporary home.

Deploy the existing Zsh configuration with:

```sh
bash ~/.dotfiles/scripts/setup/deploy-zsh-config.sh
```

To preview or selectively remove managed items:

```sh
bash ~/.dotfiles/scripts/setup/cleanup.sh
bash ~/.dotfiles/scripts/setup/cleanup.sh --apply
```

For personal/private directories, see [private profiles](private-profiles.md). Do not link empty placeholder configuration directories.
