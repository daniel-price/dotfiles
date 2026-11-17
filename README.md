# Dotfiles

Personal, cross-platform development environment for **Pop!_OS** and **macOS**.
The repository is also its own handbook: how to use it, why it is designed this
way, and what still needs building. An optional, separately authorised private
repository may provide non-public configuration on selected machines.

**Current status: declarative pinned machine tools and opt-in shell activation.**
The self-contained `get-started.sh` can install Git (when missing, after
approval) and clone this public repository once over HTTPS. `scripts/setup/bootstrap.sh`
installs missing pinned mise, then asks separately before using native mise
configuration to install missing Zsh and offer individually approved versions
of [declared machine tools](scripts/setup/mise.toml).
Curl must already exist for the standalone first download. Bootstrap offers
the reviewed Zsh startup symlink **after mise and Zsh are available and before
installing declared machine tools**. A separate opt-in script deploys one selected
private configuration directory through mise.
Existing checkouts can opt into guarded Git updates before bootstrap; automatic
recurring sync is not implemented, and secrets are not restored.

- **[Read the documentation](docs/index.md)** (source) ·
  [GitHub Pages site](https://daniel-price.github.io/dotfiles/)
- [Getting started](docs/getting-started/index.md)
- [Requirements](docs/requirements.md)
- [Architecture and tools](docs/architecture/index.md)
- [Public/private/local configuration layers](docs/architecture/private-configuration.md)
- [Roadmap](docs/roadmap.md)
- [Development tools and Git hooks](docs/guides/development.md)
- [OpenCode CLI, permissions and sandboxing](docs/guides/opencode.md)
- [Detailed reference & decisions](docs/reference/index.md)

## Start on a new machine

Copy and paste this command into a terminal on macOS or Pop!_OS. It needs
only Bash and curl; Git and GitHub SSH keys are not prerequisites.
[Review the standalone script](https://github.com/daniel-price/dotfiles/blob/main/get-started.sh)
before running downloaded code:

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

The temporary download is deleted automatically when the command finishes.
The script checks Git, asks before any installation or HTTPS clone into
`~/.dotfiles`, then **asks separately before running** the checkout's
`scripts/setup/bootstrap.sh`. Bootstrap checks mise and delegates missing Zsh and machine tools to mise; it asks
before each missing-tool installation and never upgrades an existing tool. A
missing mise installation is pinned to `v2026.11.9`, verified before execution,
and does not add shell activation. Every declared machine tool is installed only after its own confirmation;
new tools only require a pinned entry in `scripts/setup/mise.toml`. An existing
checkout is never overwritten or silently updated. When its updater is
available, stage zero offers a network fetch and an independently approved,
fast-forward-only switch/update before executing bootstrap.

Bootstrap offers the reviewed `~/.zshrc` symlink soon after mise and Zsh are
available. It previews the changes, asks separately and preserves an existing
configuration. Run `bash scripts/setup/deploy-zsh-config.sh` independently to
retry after resolving a conflict or declining the offer. New Zsh sessions add
`~/.local/bin` to `PATH` once, load the reviewed machine tool versions,
activate mise and enable zoxide’s `z` function when installed. The current Bash
shell is unchanged. Development scripts and Git hooks also resolve mise independently.

Do **not** use `curl ... | bash`: stdin must remain connected to your terminal
for confirmations, and the download must finish before execution.

## Inspect the current scaffold

From a local checkout, with Bash 3.2 or newer:

```sh
bash scripts/setup/bootstrap.sh --help
bash scripts/setup/bootstrap.sh
bash scripts/setup/deploy-zsh-config.sh --help
bash tests/run.sh
```

Bootstrap requires the repository's helper files and makes changes only when a
missing prerequisite is explicitly approved. Unattended recurring Git sync and
full configuration deployment are not implemented.
`get-started.sh` is the separate, standalone entry point.

Scripts are grouped by purpose: `scripts/setup/` installs and configures the machine;
`scripts/dev/` maintains this checkout (format, lint, hooks, CI and docs); and
`scripts/lib/` holds shared internal Bash functions. Personal commands can go
in `bin/` when there is a useful executable to expose on `PATH`.

## Safely update an existing checkout (optional)

```sh
bash scripts/setup/update.sh           # Local, read-only status
bash scripts/setup/update.sh --apply   # Confirm fetch, then switch/fast-forward
```

The first command reads local Git state without network access or modifying
refs. The second validates the public repository origin and a clean worktree,
then asks before fetching `origin/main`. If `main` can be fast-forwarded, it
asks separately before updating (and switching branches if required).
Conflicting, dirty, ahead or divergent history is never reset, stashed or
merged automatically. You can decline or remain offline and still run bootstrap
with the existing checkout.

Running `get-started.sh` for an existing checkout invokes this update offer
**before** selecting and running the checkout's bootstrap script. A fresh
clone is already on the current main, and older checkouts without the reviewed
updater remain usable but cannot update automatically. Running
`scripts/setup/bootstrap.sh` directly never changes Git branches or code.

## Develop this checkout (optional)

```sh
bash scripts/dev/run-mise.sh trust mise.toml
bash scripts/dev/install-dev-tools.sh
```

The second command installs the developer tools and offers to enable the
pre-commit Git hook with an **additional yes/no confirmation**. Noninteractive
runs (including CI) skip hook installation. The separate
`bash scripts/dev/install-hooks.sh` command remains available to enable
hooks independently.

## Preview or remove managed setup items

After bootstrapping, you can inspect an optional, conservative cleanup. Running
it **without flags never removes anything**:

```sh
bash scripts/setup/cleanup.sh           # Read-only preview
bash scripts/setup/cleanup.sh --apply   # Separate yes/no prompt per eligible item
```

Cleanup only targets the reviewed `~/.zshrc` symlink and the **exact mise
versions** currently declared in `scripts/setup/mise.toml`.
It never removes zsh/other OS packages, mise itself, Git, the checkout or
private overlays. Mise tool versions are shared across projects, so approve
their removal only if you know other projects do not rely on them.
See [cleanup details](docs/getting-started/index.md#preview-and-clean-up-managed-items).

## Safety

This is a **public** repository. Never add plaintext credentials, private age
identities, SSH private keys or other sensitive machine information. All
future modifying operations must be explicitly confirmed and must preserve
existing configuration unless a conflict is deliberately resolved.

Documentation is authoritative for current behaviour; [historical technical
plans](docs/reference/index.md) are retained for context, not as instructions.
