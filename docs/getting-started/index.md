# Getting started

Supported systems: Pop!_OS (Debian/Ubuntu-derived Linux) and macOS. **Install Git first.** Bash and curl are also required (normally present on these systems). The public repository can be cloned over HTTPS without GitHub SSH credentials.

## Install on a new machine

Review [`bin/,bootstrap`](https://github.com/daniel-price/dotfiles/blob/main/bin/,bootstrap), then run these two steps:

```sh
git clone https://github.com/daniel-price/dotfiles.git ~/.dotfiles
bash ~/.dotfiles/bin/,bootstrap --no-update
```

The second command provisions the freshly cloned revision without a redundant fetch. Bootstrap asks for confirmation before each change. It offers mise, Zsh, pinned machine tools, reviewed `~/.zshrc` and `~/.config/zellij/config.kdl` symlinks, optional pinned Powerlevel10k and Zsh autosuggestions, and Zsh as the login shell. Conflicting files are preserved; declined components can be installed later. A login-shell change takes effect on your next login.

If `~/.dotfiles` already exists, do not clone over it. Use the update commands below instead. Git must be installed separately; bootstrap does not install Git.

## Re-run or update an existing installation

From Zsh with the reviewed dotfiles configuration, run `,bootstrap` to offer
an update to the latest `main`, then bootstrap from the updated checkout.
If the fetch, branch switch or fast-forward is declined or fails, it stops
without running bootstrap. The command preserves your existing Git changes.

```sh
,bootstrap                                        # Update (with approval), then bootstrap
bash ~/.dotfiles/scripts/setup/update.sh          # Local status (no network)
bash ~/.dotfiles/scripts/setup/update.sh --apply  # Approve fetch/update
bash ~/.dotfiles/bin/,bootstrap --no-update       # Provision checked-out version only
```

The updater refuses dirty, divergent or unexpected repositories and never resets your changes. Bootstrap does not silently upgrade already installed tools.

## Common follow-up tasks

| Task | Command or guide |
| --- | --- |
| Preview or apply reviewed Zsh and Zellij dotfiles | [Manage a dotfile](../guides/manage-dotfile.md) |
| Preview optional prompt installation | `bash ~/.dotfiles/scripts/setup/setup-prompt.sh` |
| Install optional prompt after approval | `bash ~/.dotfiles/scripts/setup/setup-prompt.sh --apply` |
| Preview cleanup | `bash ~/.dotfiles/scripts/setup/cleanup.sh` |
| Approve selective cleanup | `bash ~/.dotfiles/scripts/setup/cleanup.sh --apply` |
| Develop the repository | [Development and hooks](../guides/development.md) |
| Preview or activate a Profile | [Profiles](../guides/profiles.md) |
| Manage a tool or dotfile | [Tools](../guides/add-tool.md) · [Dotfiles](../guides/manage-dotfile.md) |

Commands are also documented via `--help` where supported. For the current inventory and unfinished capabilities, see the [roadmap](../roadmap.md). **Profile selection and deactivation are available as opt-in commands**; profile Git updates and encrypted secrets management remain future work.
