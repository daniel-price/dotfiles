# Optional tool configuration

The public machine manifest links the reviewed Atuin configuration to `~/.config/atuin/config.toml` and StyLua configuration to `~/.config/stylua.toml` after approval. Existing conflicting files are preserved; bootstrap does not force-overwrite them.

Atuin is pinned in the machine manifest and offered for installation after approval. Its shell integration is **not** enabled automatically: history/output capture, background daemon autostart, and sync/account setup remain opt-in. Review your existing Atuin history and privacy requirements before running `atuin init zsh`.

StyLua applies two-space indentation when invoked; its installation and project-specific formatting rules remain independent.

The same machine manifest pins eza, jq, gum, fzf and delta. The existing Zsh `ls` alias uses eza when installed. Installing these tools does not enable fzf keybindings or replace the Git pager with delta; configure those separately if desired.
