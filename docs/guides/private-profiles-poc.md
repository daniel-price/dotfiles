# POC: real, opt-in Git repositories for machine profiles

**Status:** The command runs against an explicitly selected private Git repository and the actual dotfiles Zsh/mise setup. It is deliberately opt-in and not part of unattended bootstrap. Always review the repository before activating it.

## Layout

```text
~/.dotfiles/                          # Public checkout (never contains nested private Git repos)
~/.dotfiles-profiles/
  personal/                           # Independently cloned private Git repository
  home-server/                        # Optional second independent repository
~/.config/dotfiles/active-profiles     # Managed, ordered list of activated profile names
~/.config/mise/dotfiles-profiles.toml  # Managed effective public + profile tool pins
```

Each private repository may contain:
- `mise.toml` — exact `[tools]` pins, e.g. `opencode = "2.3.0"`. No executable mise hooks, arbitrary environment values or settings are accepted by this first implementation.
- `bin/` — executable Bash commands; added to your Zsh `PATH` from the separate checkout.
- `zsh/aliases.zsh` — aliases loaded **after** public aliases.
- `zsh/functions/` — Zsh autoload functions.
- `config/` — any nested application configuration files, mapped to corresponding `~/.config/` paths using symlinks. `config/mise` and `config/dotfiles` are reserved and rejected.

The public bootstrap remains standalone and keeps its original machine manifest. Once an approved profile is activated, **new Zsh sessions** load the generated manifest containing pinned public and selected-profile tools, plus selected bins, aliases and functions. No tool is automatically installed: the generated manifest sets `auto_install = false`.

## Try it with the personal profile fixture

Requires Git, Bash, Python **3.11+**, a checked-out `.dotfiles` PR branch and existing mise if you want to test installing tools. Set `REPO_URL` to the exact HTTPS/SSH clone URL of the approved private fixture repo (don't commit it into public files).

```sh
REPO_URL='git@github.com:OWNER/PRIVATE-PROFILE.git'    # Replace locally
bash scripts/setup/profile.sh --name personal --repo "$REPO_URL"
bash scripts/setup/profile.sh --name personal --repo "$REPO_URL" --apply
```

1. **Preview:** The first command must make **no network calls or changes**. It prints the intended checkout path.
2. **Clone approval:** The second command asks to clone, then prints the real profile's tools, shell directories and proposed app symlinks. Answer `n` here to keep the public checkout and HOME untouched.
3. **Activation approval:** After cloning, the command asks separately before creating the managed registry, effective tool manifest and symlinks. Decline here to retain just the inactive checkout.
4. **Tools:** Mise checks each private tool and asks separately before installing a missing pinned version. This fixture declares **OpenCode 2.3.0**. Its *host* install is not sandboxed, unlike the public `opencode-sandbox` command, so only approve the install if you actually want it.
5. **Check from a new Zsh session** (not an already-open shell):
   ```sh
   ,personal-hello
   personal-ping
   personal-greet world
   cat ~/.config/profile-poc/settings.toml
   cat ~/.config/mise/dotfiles-profiles.toml
   echo "$MISE_GLOBAL_CONFIG_FILE"
   opencode --version  # Only if its tool installation was approved
   ```
   The command, alias and function should print fixture greetings. The app config should contain synthetic demo settings and be a symlink to the private checkout. The generated TOML should contain both public pins and `opencode = "2.3.0"`; the environment variable should point to it.
6. **Repeat safely:** Re-running `--apply` with the same URL must not fetch, overwrite your existing app config or duplicate activation. It may re-offer declined tools. An entirely different URL for the same name must be refused.
7. **Try another profile:** Clone/apply a second independently authorised repository with `--name home-server --repo "$SERVER_URL"`. Its bins, aliases and config should join the personal profile in order. Conflicting tool pins, command names, functions or application targets are rejected.
8. **Automated:** Run `python3 tests/profile-real-repos.py`. Tests use disposable local Git remotes, a fake mise, PTY approvals and synthetic HOME. They do **not** access GitHub or install software.

### Rollback after a manual test

The profile command does **not** remove any settings automatically. To deactivate the **single personal profile** when you have no other activated profiles, inspect the following *exact* managed paths before removing them:

- `~/.config/profile-poc/settings.toml` (only if it is a symlink into the selected profile checkout)
- `~/.config/dotfiles/active-profiles` (only if its only active entry is `personal`)
- `~/.config/mise/dotfiles-profiles.toml` (only if it starts with the managed marker)

Then open a new Zsh session. The `~/.dotfiles-profiles/personal` checkout can be removed separately if you no longer want it; do not delete other private checkouts. **Installing OpenCode is not reversed by removing the profile**: mise-installed tools may be shared, so remove them separately only after checking for other dependants.

## Safety and limitations

- No private repository is discovered, implicitly cloned, fetched, pulled or pushed. Existing checkouts must have exactly the selected `origin` URL and be clean.
- Each clone, activation and missing-tool install requires independent interactive consent. Unmanaged destination files and foreign symlinks are never overwritten; profiles cannot shadow public commands or autoload functions.
- The generated files are marked as managed; the composer rejects unexpected existing files instead of silently replacing them. Shell startup sources approved profile aliases and functions from the checked-out repository, so **review their code before approving** and whenever you explicitly update the repo.
- This POC handles *file-level* conflicts, exact tool-pin conflicts and command/function-name conflicts. It does not fully analyse semantic alias collisions or merge arbitrary app settings inside an existing file.
- No credentials or private keys should go into Git. Work-specific code must remain in an employer-approved source and must not be uploaded to a personal GitHub account.
- Python 3.11+ is a current POC prerequisite, not an accepted permanent machine-bootstrap dependency.

See [existing single-directory private overlay](private-profiles.md), [configuration architecture](../architecture/private-configuration.md) and [roadmap](../roadmap.md).
