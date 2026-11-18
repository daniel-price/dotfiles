# POC: inline Zoxide bookmark suggestions

This is a **stacked POC on PR #57**, which introduces `z nvim-plugins` and `z mason-plugins`.

Uses the established [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) plugin. Its custom `dotfiles_bookmarks` strategy proposes exact bookmarked commands **before** falling back to the usual history suggestions. No shell framework is added, and missing dependencies do not break shell startup.

## Try it

Install the optional plugin, for example:

- Pop!_OS / Ubuntu: `sudo apt install zsh-autosuggestions`
- macOS with Homebrew: `brew install zsh-autosuggestions`

Open a new interactive Zsh. Type `z n` or `z m` and look for a dim completion to `z nvim-plugins` or `z mason-plugins`, respectively. Use the **Right Arrow** key to accept the suggestion. Tab completion remains independent and unchanged.

The target directories must exist for bookmark suggestions to appear. History suggestions continue to work for other commands. This POC deliberately does **not** modify bootstrap to install the plugin. If installed somewhere else, set `DOTFILES_ZSH_AUTOSUGGESTIONS_FILE=/absolute/path/to/zsh-autosuggestions.zsh` before Zsh startup.

## Checks / limitations

- A fresh shell must load PR #57's bookmarks before the suggestions strategy.
- Missing plugin: Zsh starts normally, with no inline suggestions.
- Existing `z` queries, `zi`, and Tab completion retain their original behaviour.
- Multiple bookmark prefix matches are sorted alphabetically; one suggestion is shown at a time.
- No interactive terminal rendering test runs in CI; exercise the real keypress/display behaviour manually before merging.
