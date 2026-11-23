# Dotfiles

Personal development environment for **Pop!_OS and macOS**, using Bash and mise.

**[Documentation](https://daniel-price.github.io/dotfiles/)** · [Getting started](docs/getting-started/index.md) · [Roadmap](docs/roadmap.md) · [Architecture](docs/architecture/index.md)

## Install

Install Git first. Bash and curl are also required and normally available on supported systems. Review [the bootstrap command](bin/,bootstrap), then run:

```sh
git clone https://github.com/daniel-price/dotfiles.git ~/.dotfiles
bash ~/.dotfiles/bin/,bootstrap --no-update
```

The first run uses the fresh checkout without fetching again. Bootstrap asks before installing tools or changing configuration; existing conflicts are preserved. For an existing checkout, use `,bootstrap` to offer a guarded update before provisioning.

For updating, managing tools/config, Zsh and optional rootless OpenCode, see the [guides](docs/guides/index.md). **Base** is this repository; optional reusable **Profiles** can be managed with the opt-in [Profile command](docs/guides/profiles.md). Profile Git updates and secrets management remain planned. **Never commit plaintext credentials or work-owned private files here.**

## Development

Repository maintenance lives in [`dev/`](docs/guides/development.md); machine setup is in [`setup/`](setup/), reusable helpers in [`lib/`](lib/), and executable commands in [`bin/`](bin/). Run developer checks with `mise -C dev run check` after installing the development tools.
