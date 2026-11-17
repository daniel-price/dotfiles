# Manage a dotfile

Mise manages the reviewed Zsh and Zellij symlinks declared in [`scripts/setup/mise.toml`](../../scripts/setup/mise.toml). No per-application deployment scripts are needed.

To inspect and apply these settings on an existing machine:

```sh
MISE_GLOBAL_CONFIG_FILE="$HOME/.dotfiles/scripts/setup/mise.toml" mise -C / dot diff
MISE_GLOBAL_CONFIG_FILE="$HOME/.dotfiles/scripts/setup/mise.toml" mise -C / dot apply --dry-run
MISE_GLOBAL_CONFIG_FILE="$HOME/.dotfiles/scripts/setup/mise.toml" mise -C / dot apply
```

Alternatively, rerun `bash ~/.dotfiles/scripts/setup/bootstrap.sh` to provision tools and offer the reviewed dotfiles.

Mise refuses to replace existing regular files without `--force`, but may repoint an existing symlink to the declared source. Review the preview and never use `--force` during bootstrap. The manifest stays separate from the checkout-only development `mise.toml`.

For removal, preview with `bash ~/.dotfiles/scripts/setup/cleanup.sh` and approve selective cleanup with `--apply`. See [Zellij keybindings](zellij.md) and [private profiles](private-profiles.md).
