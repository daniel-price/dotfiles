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

Use `,bootstrap --verbose` to show full third-party output. By default, bootstrap summarises installed tools and suppresses routine command output; prompts and failed command diagnostics remain visible.

## Neovim

Bootstrap syncs the [LazyVim configuration](https://github.com/daniel-price/lazyvim) and restores plugins from its lockfile. Close running Neovim sessions before bootstrapping. Plugin restoration, Mason tools and Tree-sitter parsers run in one headless session with live progress; the tracked lockfile is not updated by bootstrap.

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
