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
  [GitHub Pages site](https://daniel-price.github.io/dotfiles/)
- [Getting started](docs/getting-started/index.md)
- [Requirements](docs/requirements.md)
- [Architecture and tools](docs/architecture/index.md)
- [Public/private/local configuration layers](docs/architecture/private-configuration.md)
- [Roadmap](docs/roadmap.md)
- [Detailed reference & decisions](docs/reference/index.md)

## Start on a new machine

Copy and paste this command into a terminal on macOS or Pop!_OS. It needs
only Bash and curl; Git and GitHub SSH keys are not prerequisites.
[Review the standalone script](https://github.com/daniel-price/dotfiles/blob/main/get-started.sh)
before running downloaded code:

```sh
(
  tmp_dir=$(mktemp -d) || exit 1
  trap 'rm -rf "$tmp_dir"' EXIT
  curl -fsSLo "$tmp_dir/get-started.sh" \
    https://raw.githubusercontent.com/daniel-price/dotfiles/main/get-started.sh &&
    bash "$tmp_dir/get-started.sh"
)
```

The temporary download is deleted automatically when the command finishes.
The script checks Git, asks before any installation or HTTPS clone into
`~/.dotfiles`, then **asks separately before running** the checkout's
`bootstrap.sh`. That bootstrap remains read-only scaffolding for now.
An existing checkout is neither overwritten nor automatically updated.

Do **not** use `curl ... | bash`: stdin must remain connected to your terminal
for confirmations, and the download must finish before execution.

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
