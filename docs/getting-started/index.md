# Getting started

Pop!_OS and macOS. Requires Git, Bash and curl.

## Install

```sh
git clone https://github.com/daniel-price/dotfiles.git ~/.dotfiles
bash ~/.dotfiles/bin/,bootstrap --no-update
```

## Update

```sh
,bootstrap
```

## Neovim

Bootstrap syncs the [LazyVim configuration](https://github.com/daniel-price/lazyvim) and restores plugins from its lockfile.

```sh
,nvim-update
```

Updates plugins and commits/pushes the lockfile.
