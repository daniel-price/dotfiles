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

For updating, managing tools/config, Zsh and optional rootless OpenCode, see the [guides](docs/guides/index.md). Secrets and full private-profile management remain planned. **Never commit plaintext credentials or work-owned private files here.**
