# Profiles: opt-in Git repositories (POC)

**Status:** The command runs against an explicitly selected profile Git repository and the actual dotfiles Zsh/mise setup. It is deliberately opt-in and not part of unattended bootstrap. Always review the repository before activating it.

## Layout

Profiles are **reusable configuration bundles**, not a synonym for private files or one specific machine. One device can enable multiple profiles (such as `personal` and `work`); one profile can be used on several devices. The **Base** is the public `dotfiles` checkout and always works independently. Repo visibility and credentials are separate security concerns. **Local** per-device configuration is deferred; nothing in this POC loads a Local layer.


```text
~/.dotfiles/                          # Base configuration (standalone public checkout)
~/.dotfiles-profiles/
  personal/                           # Independent profile Git repository
  home-server/                        # Optional second independent repository
~/.config/dotfiles/active-profiles     # Managed, ordered list of activated profile names
~/.config/mise/dotfiles-profiles.toml  # Managed tool pins and non-secret profile environment
```

Each profile repository may contain:
- `mise.toml` — exact `[tools]` pins, e.g. `opencode = "2.3.0"`, plus optional literal non-secret `[env]` string values such as `EDITOR = "nvim"`. Conflicting variables and reserved runtime variables (including `PATH`, `HOME` and `MISE_*`) are rejected. No executable mise hooks or arbitrary settings are accepted.
- `bin/` — executable Bash commands; added to your Zsh `PATH` from the separate checkout.
- `zsh/aliases.zsh` — aliases loaded **after** public aliases.
- `zsh/functions/` — Zsh autoload functions.
- `config/` — any nested application configuration files, mapped to corresponding `~/.config/` paths using symlinks. `config/mise` and `config/dotfiles` are reserved and rejected.

The Base bootstrap remains standalone and keeps its original tool manifest. Once an approved profile is activated, **new Zsh sessions** load the generated manifest containing pinned Base and selected-profile tools and declared environment variables, plus selected bins, aliases and functions. No tool is automatically installed: the generated manifest sets `auto_install = false`.

## Try it with the personal profile fixture

Requires Git, Bash, Python **3.11+**, a checked-out `.dotfiles` PR branch and existing mise if you want to test installing tools. Set `REPO_URL` to the exact HTTPS/SSH clone URL of the approved private fixture repo (don't commit it into public files).

```sh
REPO_URL='git@github.com:OWNER/PROFILE_REPO.git'    # Replace locally
bash scripts/setup/profile.sh --name personal --repo "$REPO_URL"
bash scripts/setup/profile.sh --name personal --repo "$REPO_URL" --apply
```

1. **Preview:** The first command must make **no network calls or changes**. It prints the intended checkout path.
2. **Clone approval:** The second command asks to clone, then prints the real profile's tools, shell directories and proposed app symlinks. Answer `n` here to keep the public checkout and HOME untouched.
3. **Activation approval:** After cloning, the command asks separately before creating the managed registry, effective tool manifest and symlinks. Decline here to retain just the inactive checkout.
4. **Tools:** Mise checks each private tool and asks separately before installing a missing pinned version. This fixture declares **OpenCode 2.3.0**. Its *host* install is not sandboxed, unlike the Base `opencode-sandbox` command, so only approve the install if you actually want it.
5. **Check from a new Zsh session** (not an already-open shell):
   ```sh
   ,personal-hello
   personal-ping
   personal-greet world
   cat ~/.config/profile-poc/settings.toml
   cat ~/.config/mise/dotfiles-profiles.toml
   echo "$MISE_GLOBAL_CONFIG_FILE"
   echo "$DOTFILES_PROFILE_EXAMPLE"  # personal-profile-active
   echo "$EDITOR"                    # nvim
   opencode --version  # Only if its tool installation was approved
   ```
   The command, alias and function should print fixture greetings. The app config should contain synthetic demo settings and be a symlink to the private checkout. The generated TOML should contain both Base pins and `opencode = "2.3.0"`, alongside `[env]` values such as `EDITOR = "nvim"`. `MISE_GLOBAL_CONFIG_FILE` should point to it.
6. **Repeat safely:** Re-running `--apply` with the same URL must not fetch, overwrite your existing app config or duplicate activation. It may re-offer declined tools. An entirely different URL for the same name must be refused.
7. **Try another profile:** Clone/apply a second independently authorised repository with `--name home-server --repo "$SERVER_URL"`. Its bins, aliases and config should join the personal profile in order. Conflicting tool pins, command names, functions or application targets are rejected.
8. **Automated:** Run `python3 tests/profile-real-repos.py`. Tests use disposable local Git remotes, a fake mise, PTY approvals and synthetic HOME. They do **not** access GitHub or install software.

### Preview, deactivate and recover

Deactivation is a supported POC operation. It does **not** delete cloned repositories or uninstall tools:

```sh
bash scripts/setup/profile.sh --name personal --deactivate          # Preview only
bash scripts/setup/profile.sh --name personal --deactivate --apply  # Confirm
```

After approval, only verified symlinks owned by `personal` are removed, and the effective tool/environment manifest and active-profile list are recomputed for any remaining profiles. If this was the **last active profile**, the two generated managed files are removed, and a new Zsh session falls back to the Base tool manifest. The cloned repository and installed OpenCode are left untouched. Repeating deactivation is a no-op.

If a config path has been replaced by a different symlink or a real file, deactivation **refuses** to remove it. For recovery, inspect the conflicting path and restore the original profile-owned symlink before re-running. It does not blindly remove or overwrite anything.

To reactivate the retained checkout, use the original `--name personal --repo "$REPO_URL" --apply` command and review the prompts; no automatic fetch/pull is performed. General Git profile updates and automated version rollback remain follow-up work.

## Safety and limitations

- No profile repository is discovered, implicitly cloned, fetched, pulled or pushed. Existing checkouts must have exactly the selected `origin` URL and be clean.
- Each clone, activation, deactivation and missing-tool install requires independent interactive consent. Unmanaged destination files and foreign symlinks are never overwritten; profiles cannot shadow public commands or autoload functions.
- The generated files are marked as managed; the composer rejects unexpected existing files instead of silently replacing them. Shell startup sources approved profile aliases and functions from the checked-out repository, so **review their code before approving** and whenever you explicitly update the repo.
- This POC handles *file-level* conflicts, exact tool-pin and environment conflicts, and command/function-name conflicts. It does not fully analyse semantic alias collisions or merge arbitrary app settings inside an existing file.
- No credentials or private keys should go into Git. Work-specific code must remain in an employer-approved source and must not be uploaded to a personal GitHub account.
- Python 3.11+ is a current POC prerequisite, not an accepted permanent machine-bootstrap dependency.

See [legacy directory-link helper](directory-link.md), [configuration architecture](../architecture/configuration.md) and [roadmap](../roadmap.md).
