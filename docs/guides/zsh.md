# Zsh aliases, navigation, prompt and autosuggestions

The [Zsh profile](../../.config/zsh/zshrc) activates mise, loads reviewed aliases and configures zoxide. Optional [Profiles](profiles.md) are loaded via `.config/zsh/profiles.zsh` after explicit activation.

## Zoxide bookmarks

Use `z nvim-plugins` and `z mason-plugins` to jump to Neovim directories. Other `z` queries still use zoxide. Tab completion works independently of autosuggestions.

## Inline autosuggestions

The optional [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) plugin shows suggested commands in muted text. Typing `z n` suggests `z nvim-plugins` when the directory exists. If there is no matching bookmark, it suggests from command history. Press **Right Arrow** (or **End**) to accept and **Enter** to execute.

Bootstrap offers a **commit-pinned Git checkout** at `~/.local/share/dotfiles/zsh-autosuggestions`. Preview or approve it separately:

```sh
bash ~/.dotfiles/scripts/setup/setup-autosuggestions.sh
bash ~/.dotfiles/scripts/setup/setup-autosuggestions.sh --apply
```

Every install requires approval. The shell starts normally without the plugin; startup never downloads anything. Existing/conflicting plugin directories are preserved. System packages (`apt install zsh-autosuggestions`, `brew install zsh-autosuggestions`) are also supported. Set `DOTFILES_ZSH_AUTOSUGGESTIONS_FILE` to load an explicit plugin file.

## Prompt

Powerlevel10k is a separate optional pinned checkout, offered by `scripts/setup/setup-prompt.sh`. It loads outside VS Code with the reviewed `p10k.zsh` configuration.

The prompt expects **MesloLGS NF**, Powerlevel10k's recommended Nerd Font. The reviewed Ghostty configuration (`~/.config/ghostty/config`) selects it. Bootstrap offers to install the four font faces alongside the optional Zsh prompt setup, regardless of terminal; headless machines can decline, and existing user font files are never overwritten.

Preview or install missing faces manually on macOS or Pop!_OS:

```sh
bash ~/.dotfiles/scripts/setup/setup-fonts.sh
bash ~/.dotfiles/scripts/setup/setup-fonts.sh --apply
```

Fonts are downloaded from an immutable `powerlevel10k-media` commit. Installation is user-local (`~/.local/share/fonts` on Linux, `~/Library/Fonts` on macOS), without elevated privileges. Restart Ghostty or reload its configuration after installation. On macOS, Ghostty's application-specific config may override the shared config. If another terminal renders the prompt, select `MesloLGS NF` in that terminal too.

## Manual verification

1. Open interactive Zsh, type `z n`, and verify the remainder of `nvim-plugins` is dimmed (when its target exists).
2. Press Right Arrow then Enter; it should navigate to the bookmarked directory.
3. Type an earlier non-bookmark command prefix; a history-based suggestion should appear.
4. Check `zi` and Tab completion, then test starting Zsh without the optional plugin.
