# Zsh aliases and Powerlevel10k prompt

The reviewed baseline keeps [`.config/zsh/zshrc`](../../.config/zsh/zshrc)
small and sources two separate files:

- [`.config/zsh/aliases.zsh`](../../.config/zsh/aliases.zsh) for portable aliases.
- [`.config/zsh/p10k.zsh`](../../.config/zsh/p10k.zsh) for the **unchanged**
  Powerlevel10k appearance migrated from the old personal `.cfg/.p10k.zsh`.

## Aliases migrated

| Alias | Meaning |
| --- | --- |
| `zj` | `zellij` |
| `za` | `zellij action` |
| `zar` | `zellij action rename-tab` |
| `g` | `git` |
| `..`, `...`, `....` | Move up one, two or three directories |
| `hl` | `rg --passthru` |
| `m` and `p` | `mise` and `pnpm`, only if the tools are available |
| `ls` | `eza`, only when `eza` is installed; otherwise the system `ls` remains |

No aliases execute anything at startup. Work-specific functions,
machine-specific paths, deprecated tmux helpers and destructive commands
were intentionally **not** copied from the old `.functions/bash_functions.sh`.

## Declarative, optional prompt installation

Powerlevel10k is a Zsh theme, **not** a regular mise-hosted executable.
The pinned Git repository is declared separately in
[`scripts/setup/prompt.toml`](../../scripts/setup/prompt.toml) using mise's
native `[bootstrap.repos]` support. It uses the official Powerlevel10k
**v1.20.0** release commit
`35833ea15f14b71dbcebc7e54c104d8d56ca5268`.

The checked-out theme lives at
`~/.local/share/dotfiles/powerlevel10k`, outside your dotfiles Git checkout.
The managed `.zshrc` sources it only if its theme file exists and the shell
is interactive. **No downloads, package installation or Git operations
happen when Zsh starts**; without the theme, Zsh starts with its normal
prompt and all available aliases.

Bootstrap offers the theme **after** other machine tools are checked,
and only when the reviewed `~/.zshrc` symlink is already in place.
The theme is a separate, optional confirmation. To inspect it independently:

```bash
bash scripts/setup/setup-prompt.sh           # Preview; no changes
bash scripts/setup/setup-prompt.sh --apply   # Preview, then ask to clone
```

The installer uses `MISE_GLOBAL_CONFIG_FILE` and `mise -C /` to isolate the
single prompt repository from project tools and other mise settings.
If the checkout already exists, it is **never upgraded, overwritten,
recloned or deleted automatically**. A conflicting directory remains
untouched. Run `mise bootstrap repos status` using the prompt manifest to
diagnose a revision mismatch before deciding whether to update it yourself.

Existing legacy paths `~/powerlevel10k` and `~/.p10k.zsh` are not deleted
or changed. The new reviewed config lives in the repo and does **not**
require a symlink at `~/.p10k.zsh`.

## Prompt appearance and terminals

Powerlevel10k reads your original classic, two-line prompt settings
without re-running its configuration wizard. The old instant-prompt
cache is loaded early when available, except in the VS Code integrated
terminal, matching the previous setup.

**Fonts are separate:** your old config uses Nerd Font glyphs. To
see the same symbols in Ghostty, select an appropriate Nerd Font
such as MesloLGS NF in that terminal's font settings; this PR does
not install or change fonts. Your terminal and font may affect how
the otherwise-identical settings render.

After the bootstrap/install prompt, start a **new Zsh session** to load
the updated aliases and theme. A Bash terminal will not load `.zshrc`,
even if it is symlinked correctly. A previous bootstrap PR sets Zsh as
the *default login shell* after its own confirmation.

## Out of scope

Zellij keybindings/layouts, Atuin, autosuggestions, syntax highlighting,
private profiles and work-specific functions are separate migrations.
None is silently installed, sourced or published by this PR.
