# Optional tool configuration

The public machine manifest links the reviewed Atuin configuration to `~/.config/atuin/config.toml` and StyLua configuration to `~/.config/stylua.toml` after approval. Existing conflicting files are preserved; bootstrap does not force-overwrite them.

Neither tool is installed by this change. Atuin only uses these preferences when it is installed and initialised separately. **History/output capture, background daemon autostart and sync/account setup are deliberately not enabled.** Review your existing Atuin history and privacy requirements before enabling it.

StyLua applies two-space indentation when invoked; its installation and project-specific formatting rules remain independent.
