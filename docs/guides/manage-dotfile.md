# Manage a dotfile

Declare targets in [src/mise.toml](../../src/mise.toml).

```sh
bash ~/.dotfiles/src/bin/,bootstrap --no-update
```

Preview or apply cleanup of managed machine dotfiles and pinned tools:

```sh
bash ~/.dotfiles/src/lib/setup/cleanup.sh
bash ~/.dotfiles/src/lib/setup/cleanup.sh --apply
```

For a full reset, see [Getting started](../getting-started/index.md#reset-an-existing-installation).
