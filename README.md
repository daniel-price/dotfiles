# Dotfiles

Personal, cross-platform development environment for **Pop!_OS** and **macOS**.
The repository is also its own handbook: how to use it, why it is designed this
way, and what still needs building. An optional, separately authorised private
repository may provide non-public configuration on selected machines.

**Current status: stage-zero acquisition plus read-only scaffold.** The new
self-contained `get-started.sh` can install Git (when missing, after approval)
and clone this public repository once over HTTPS. `bootstrap.sh` and
`update.sh` do **not** yet install mise, configure dotfiles or restore secrets.

- **[Read the documentation](docs/index.md)** (source) ·
  [GitHub Pages site](https://daniel-price.github.io/dotfiles/) (available after
  this change is merged and Pages is configured)
- [Getting started](docs/getting-started/index.md)
- [Requirements](docs/requirements.md)
- [Architecture and tools](docs/architecture/index.md)
- [Public/private/local configuration layers](docs/architecture/private-configuration.md)
- [Roadmap](docs/roadmap.md)
- [Detailed reference & decisions](docs/reference/index.md)

## Start on a new machine

Download **one small script**, review it, then run it. Git and GitHub SSH keys
are not prerequisites:

```sh
curl -fsSLo dotfiles-get-started.sh https://raw.githubusercontent.com/daniel-price/dotfiles/main/get-started.sh && bash dotfiles-get-started.sh
```

This checks whether Git is usable, asks before installing it if missing, then
asks before cloning into `~/.dotfiles`. It does not download a ZIP, alter
existing Git settings or execute code from the new checkout automatically.
For now, the checkout bootstrap is read-only:

```sh
bash ~/.dotfiles/bootstrap.sh
```

Do **not** use `curl ... | bash`: interactive stdin is required for approval.

## Inspect the current scaffold

From a local checkout, with Bash 3.2 or newer:

```sh
bash bootstrap.sh --help
bash bootstrap.sh
bash update.sh
bash tests/run.sh
```

`bootstrap.sh` and `update.sh` are still read-only and require sibling files
in their checkout. `get-started.sh` is the separate, standalone entry point.

## Safety

This is a **public** repository. Never add plaintext credentials, private age
identities, SSH private keys or other sensitive machine information. All
future modifying operations must be explicitly confirmed and must preserve
existing configuration unless a conflict is deliberately resolved.

Documentation is authoritative for current behaviour; [historical technical
plans](docs/reference/index.md) are retained for context, not as instructions.
