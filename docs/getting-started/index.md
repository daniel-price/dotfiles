# Getting started

Pop!_OS and macOS. Requires Git, Bash and curl.

## Install

```sh
git clone https://github.com/daniel-price/dotfiles.git ~/.dotfiles
bash ~/.dotfiles/src/bin/,bootstrap --no-update
```

## Update

```sh
,bootstrap
```

Use `,bootstrap -v` or `,bootstrap --verbose` to stream full command output. By default, bootstrap displays only task progress, ticks/crosses and interactive prompts. Answered prompts are cleared on supported terminals: approvals give way to progress, while declines remain as a cross labelled `Declined`. Routine messages, package previews and subprocess diagnostics are written to private logs under `${XDG_STATE_HOME:-~/.local/state}/dotfiles/logs/`. After mise installs the pinned Gum version, eligible steps use a spinner that clears and becomes a tick or cross on the same line. Before Gum is installed (or if its renderer fails), the same steps use an animated Bash spinner. Non-TTY execution prints only completed statuses. Ctrl+C cancels the active step rather than triggering a renderer fallback. No shell restart is required. On Linux, sudo authenticates before the OS package installation spinner starts; expired authorisation fails rather than prompting behind the spinner. Homebrew and login-shell changes retain native authentication prompts. Secret-bearing commands must not use logged steps.

## Neovim

Bootstrap syncs the [LazyVim configuration](https://github.com/daniel-price/lazyvim) and restores plugins from its lockfile. Close running Neovim sessions before bootstrapping. Plugin restoration, Mason tools and Tree-sitter parsers run in one headless session with a progress indicator; the tracked lockfile is not updated by bootstrap.

```sh
,nvim-update
```

Updates plugins and commits/pushes the lockfile.

## Reset an existing installation

Use a fresh copy of the standalone cleanup command (it does not need the old checkout to be updated or mise to work):

```sh
reset=$(mktemp)
curl -fsSL https://raw.githubusercontent.com/daniel-price/dotfiles/main/src/bin/%2Ccleanup -o "$reset"
bash "$reset"
bash "$reset" --apply --remove-checkout
rm -f "$reset"
```

Review every removal. The reset removes known managed links even if broken, offers to remove managed optional components, and can remove a clean checkout. It preserves unrelated files, shared system packages, credentials and dirty repositories; exact pre-install state cannot be reconstructed without prior backups. Restore or move conflicting files before reinstalling. When the old checkout has been removed, use the Install commands above.
