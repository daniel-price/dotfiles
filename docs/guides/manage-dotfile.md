# Manage a dotfile

**Status: partly implemented.** A reviewed zsh startup file can be deployed
through mise, and one explicitly selected private directory can be linked. Other
dotfiles remain planned.

1. Identify the source file and its intended home-directory target.
2. Remove secret values and work-specific content; use only explicitly reviewed
   config files.
3. Declare a **single** mise-managed target rather than linking a whole
   application directory or adding a bespoke symlink manager.
4. Preview the proposed diff and inspect existing files or symlinks.
5. Require a precise yes/no prompt for every modifying action.
6. Test refusal, already-correct state, conflicts and reruns in an isolated HOME.

To activate mise in a new zsh session:

```sh
bash ~/.dotfiles/scripts/setup/deploy-zsh-config.sh --help
bash ~/.dotfiles/scripts/setup/deploy-zsh-config.sh
```

The target and source are declared once in `scripts/setup/mise.toml` under `[dotfiles]`, rather than generated as temporary TOML. The source is `.config/zsh/zshrc`. It adds `~/.local/bin` to `PATH` once
then activates mise from there or an existing `PATH` executable. An existing `~/.zshrc` is never overwritten: resolve that
conflict manually before rerunning. A repeated run with the correct symlink
exits without a prompt.

To preview or selectively remove the reviewed Zsh symlink, use
`bash ~/.dotfiles/scripts/setup/cleanup.sh` (preview) or append `--apply`
(interactive). Only the symlink pointing to this checkout's source is eligible;
ordinary files and different symlinks are never modified. Other private
configuration overlays are deliberately excluded from cleanup.

Existing `.config/nvim`, `.config/zellij` and `.config/ghostty` are still empty
placeholders. See [Getting started](../getting-started/index.md) and
[architecture](../architecture/index.md) for context.
