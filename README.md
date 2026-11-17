# Dotfiles

Personal development environment for **Pop!_OS and macOS**, using Bash and mise.

**[Documentation](https://daniel-price.github.io/dotfiles/)** · [Getting started](docs/getting-started/index.md) · [Roadmap](docs/roadmap.md) · [Architecture](docs/architecture/index.md)

## Install

Requires Bash and curl. Review [the installer](get-started.sh) first:

```sh
(
  tmp_dir=$(mktemp -d) || exit 1
  script="$tmp_dir/get-started.sh"
  trap 'rm -rf "$tmp_dir"' EXIT
  curl -fsSLo "$script" \
    https://raw.githubusercontent.com/daniel-price/dotfiles/main/get-started.sh &&
    bash "$script"
)
```

Git is installed if missing, the repo is cloned to `~/.dotfiles`, and bootstrap is offered. Changes require confirmation; existing conflicting files are preserved.

For updating, managing tools/config, Zsh and optional rootless OpenCode, see the [guides](docs/guides/index.md). Secrets and full private-profile management remain planned. **Never commit plaintext credentials or work-owned private files here.**
