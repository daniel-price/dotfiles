# Zellij keybindings

The reviewed Zellij config is copied from the personal `.cfg` keybindings, with machine-specific paths replaced by `~/.dotfiles` and cross-platform clipboard handling.

Deploy it on an existing machine:

```sh
bash ~/.dotfiles/scripts/setup/bootstrap.sh
```

Bootstrap uses mise's reviewed dotfile manifest to offer Zsh and Zellij together. After you approve deployment, an existing regular Zellij config is moved to a timestamped `config.kdl.backup-*` file before the managed symlink is installed. It never uses blanket `--force`, and foreign symlinks or other file types are left untouched. If deployment fails before replacing the target, the backup is restored. Review the preview first. Restart Zellij after deploying.

Zellij starts in locked mode. Press **Ctrl+A** to enter command mode, then **Y** to enter the yank menu:

- **A** copies the active pane's full scrollback.
- **L** copies the most recent shell command and its output, when available.
- **P** opens the interactive command picker.

Clipboard support uses `pbcopy` (macOS), `wl-copy` (Wayland), `xclip` or `xsel` (X11). Install one appropriate to your session. The L/P helpers also need `atuin`, and P needs `fzf`; output capture is best-effort. The locked-mode Ctrl+H/J/K/L navigation uses the external vim-zellij-navigator plugin, fetched by Zellij when invoked.

The source files are `.config/zellij/config.kdl`, `bin/,copy-*` and `bin/lib/*`. The copy scripts are run with Bash, so Git executable bits are not required.
