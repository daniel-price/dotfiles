# POC: independent Git repositories for machine profiles

**Status:** Experimental, synthetic local repositories only. No private GitHub repositories, actual HOME directories, tool installations, or real employer-owned configuration are used. Nothing is integrated into production bootstrap.

Question: can **one separate private repository per machine profile** combine with the public dotfiles baseline, including when multiple profiles apply to the same machine, without leaking unselected settings or silently resolving conflicts?

## Layout being tested

The POC creates **three independently committed local Git repositories** in a disposable workspace. They have different `.git` directories and no remotes. For real use, the proposed checkout layout is separate from the public dotfiles repo:

```text
~/.dotfiles/                         # Public dotfiles Git repository (unchanged)
~/.dotfiles-profiles/
  personal-profile/                 # One optional private Git repository
  home-server-profile/              # Another optional private Git repository
  work-mac-profile/                 # Another optional, approved source
```

Each profile repository has its own `mise.toml`, `bin/`, `zsh/aliases.zsh`, and `config/demo/` files. The work-mac fixture contains **synthetic examples only**, not employer-owned files. A real work profile would have to remain local or use an employer-approved source.

The public defaults are staged first, followed by selected profiles in the order supplied. Example: `personal,work-mac` yields shared ripgrep plus personal `gh` plus work-mac `node`, with matching aliases, commands and demo config. An unselected home-server profile remains a separate repository but is **not** staged.

## Run

Review the script, then run from the public dotfiles checkout:

```sh
bash scripts/poc/private-profiles.sh
bash scripts/poc/private-profiles.sh --apply personal
# Or a single server profile:
bash scripts/poc/private-profiles.sh --apply home-server
# Or more than one profile on a machine:
bash scripts/poc/private-profiles.sh --apply personal,work-mac
```

The default only previews. `--apply` requires an interactive terminal and explicit `y` confirmation. Declining creates nothing. Approving creates a disposable workspace under `${TMPDIR:-/tmp}` with `profile-repos/`, a synthetic `public-fixture/` and a `staged-home/` directory. The `staged-home/` contains only hidden `.config/` and `.local/` directories, so use `ls -la` or `find . -type f` to see it.

- **Tools:** `scripts/poc/private-profile-tools.py` merges only exact `[tools]` version pins, refuses conflicting versions or overwriting a pre-existing manifest, and sets `auto_install = false`. This is *not* real mise layering, installation or trust handling. Do not run `mise trust` for this POC.
- **Commands:** Synthetic Bash executables are copied, never executed. Duplicate output paths are rejected.
- **Aliases:** The shared aliases and selected profile aliases are concatenated as **inert text**, never sourced. Semantic alias conflicts still need a production design.
- **App config:** Demo files are copied, refusing duplicate destination names. General application-specific merges are out of scope.

## Manual acceptance and cleanup

1. Run without arguments; expect preview, no files created.
2. Run `--apply personal` and answer `n`; expect no workspace.
3. Repeat and answer `y`; inspect the printed `staged-home/`: shared `ripgrep`, `gh`, `,personal-demo`, `poc_personal`, and `personal.conf`, but **no** home-server or work-mac entries.
4. Run `--apply home-server` and approve; expect shared `ripgrep` plus `fd`, `,server-demo`, `poc_server` and `server.conf`, with no personal-only entries.
5. Run `--apply personal,work-mac` and approve; expect shared plus **both** selected profiles (`gh`, `node`, both commands, both aliases, both config files), and no home-server entries.
6. Inspect all three local repositories, for example `git -C <workspace>/profile-repos/personal-profile log -1` and `git -C <workspace>/profile-repos/personal-profile remote -v`. Each has its **own commit**; all have **no remotes**. There should be no `.git` in the parent `profile-repos/` directory.
7. Run `python3 tests/private-profiles-poc.py`. Expect `PASS`; it tests consent, profile selection and layering, separate Git histories, conflicting tool pins, non-overwrite and isolation from a sentinel HOME. Requires Python 3.11+, Git and Bash. Tests also run via the existing shell CI flow.
8. Remove **only** the disposable workspace paths printed by the script after inspection; never delete your real HOME or actual dotfiles checkout.

## What this POC does not prove

It does **not** clone, authenticate to, update or push actual private GitHub repositories, automatically select profiles, install tools, change real shell configurations or integrate into bootstrap. A later PR should ask for explicit authorised repo URLs and profile selection, preview all affected paths, support secure clone/update and deal with alias/app conflicts, precedence, migration and rollback. Never commit secrets or employer-owned code to an unauthorised account.

See [private configuration](private-profiles.md), [architecture](../architecture/private-configuration.md), and [roadmap](../roadmap.md).
