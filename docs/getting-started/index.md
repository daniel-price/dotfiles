# Getting started

Supported systems: Pop!_OS (Debian/Ubuntu-derived Linux) and macOS. Requires **Bash and curl**. Git and GitHub SSH access are not required initially.

## Install on a new machine

Review [get-started.sh](https://github.com/daniel-price/dotfiles/blob/main/get-started.sh), then run:

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

The script can install missing Git, clone to `~/.dotfiles` and offer to run bootstrap. **Each change requires confirmation.** Existing files and conflicting checkouts are preserved. Do not pipe the download directly into Bash; the script needs interactive input.

Bootstrap then offers the reviewed mise, Zsh and pinned machine tools. It also offers mise-managed `~/.zshrc` and `~/.config/zellij/config.kdl` symlinks, installs the optional Powerlevel10k theme and set Zsh as your login shell. The latter takes effect on your next login, not in the current terminal. Declined components can be installed later.

## Re-run or update an existing installation

From Zsh with the reviewed dotfiles configuration, run `,bootstrap` to offer
an update to the latest `main`, then bootstrap from the updated checkout.
If the fetch, branch switch or fast-forward is declined or fails, it stops
without running bootstrap. The command preserves your existing Git changes.

```sh
,bootstrap                 # Update (with approval), then bootstrap
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
| Apply private configuration | [Private profiles](../guides/private-profiles.md) |
| Manage a tool or dotfile | [Tools](../guides/add-tool.md) · [Dotfiles](../guides/manage-dotfile.md) |

Commands are also documented via `--help` where supported. For the current inventory and unfinished capabilities, see the [roadmap](../roadmap.md). **Encrypted secrets and full private profile composition are not yet implemented.**
