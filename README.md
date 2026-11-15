# Dotfiles

Personal, cross-platform development environment for **Pop!_OS** and **macOS**.
The repository is also its own handbook: how to use it, why it is designed this
way, and what still needs building.

**Current status: scaffold only.** `bootstrap.sh` and `update.sh` detect the
platform and report unimplemented work. They do **not** yet install packages,
clone repositories, manage dotfiles or restore secrets.

- **[Read the documentation](docs/index.md)** (source) ·
  [GitHub Pages site](https://daniel-price.github.io/dotfiles/) (available after
  this change is merged and Pages is configured)
- [Getting started](docs/getting-started/index.md)
- [Requirements](docs/requirements.md)
- [Architecture and tools](docs/architecture/index.md)
- [Roadmap](docs/roadmap.md)
- [Detailed reference & decisions](docs/reference/index.md)

## Inspect the current scaffold

From a local checkout, with Bash 3.2 or newer:

```sh
bash bootstrap.sh --help
bash bootstrap.sh
bash update.sh
bash tests/run.sh
```

These are currently read-only. `bootstrap.sh` requires the sibling files in
this checkout; **do not** pipe it directly from a URL into a shell.

## Safety

This is a **public** repository. Never add plaintext credentials, private age
identities, SSH private keys or other sensitive machine information. All
future modifying operations must be explicitly confirmed and must preserve
existing configuration unless a conflict is deliberately resolved.

Documentation is authoritative for current behaviour; [historical technical
plans](docs/reference/index.md) are retained for context, not as instructions.
