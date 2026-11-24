# Dotfiles

Personal development environment for Pop!_OS and macOS.

[Documentation](https://daniel-price.github.io/dotfiles/)

## Install

Requires Git, Bash and curl.

```sh
git clone https://github.com/daniel-price/dotfiles.git ~/.dotfiles
bash ~/.dotfiles/src/bin/,bootstrap --no-update
```

Update an existing installation: `,bootstrap`.

## Development

```sh
bash dev/scripts/install-dev-tools.sh
mise -C dev run check
```

For a fresh start from an older layout, see [reset an existing installation](docs/getting-started/index.md#reset-an-existing-installation).
