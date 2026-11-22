# POC: machine-specific profiles from an optional private Git repository

**Status:** Experimental; local synthetic Git fixture only. Not integrated into bootstrap, not an actual private GitHub repository, and no packages or scripts are installed or executed.

Question: can a shared dotfiles baseline be combined with exactly one optional profile (laptop or home-server), spanning pinned tools, Bash commands, Zsh aliases and application settings, without leaking the other profile or changing a real HOME?

## Run

From a checkout, review the script, then:

```sh
bash scripts/poc/private-profiles.sh
bash scripts/poc/private-profiles.sh --apply laptop
# Or, independently:
bash scripts/poc/private-profiles.sh --apply home-server
```

The default **previews only**. Applying requires terminal confirmation; declining creates nothing. The approved experiment creates a disposable workspace under `${TMPDIR:-/tmp}` containing a newly initialised, committed **local Git repository** (`private-fixture/`) with two synthetic profiles. It creates a small synthetic shared baseline separately. The selected profile is staged into a disposable `staged-home/`; the other profile remains in the fixture repo but is not staged. No private repositories, credentials, actual HOME paths, installation commands, automatic shell loading or remote GitHub services are touched. The fake Git repository has **no remote**; it is not access-controlled storage.

Each profile demonstrates:

- `mise.toml`: exact version pins for additional tools; `scripts/poc/private-profile-tools.py` combines only `[tools]` entries with shared pins, refuses conflicting versions and writes `auto_install = false`. It does not run `mise install` or claim to implement mise's general configuration precedence.
- `bin/`: extra synthetic Bash commands alongside shared commands, with collisions refused.
- `zsh/aliases.zsh`: shared aliases followed by the chosen profile's aliases, written as text but **never sourced**.
- `config/demo/`: example application preferences, with target collisions refused.

The POC deliberately uses conservative, non-overlapping fixture settings. Real application config merges, overriding alias definitions, source validation, mise trust semantics and profile updates still need a design and tests before production integration.

## Acceptance and cleanup

1. Run without arguments: expect preview, no files.
2. Run `--apply laptop` and answer `n`: expect no files.
3. Run `--apply laptop` and answer `y`: note workspace path. Check selected `staged-home/` has shared values, `gh`, `,laptop-demo`, `poc_laptop`, and `laptop.conf`, but no server-only entries.
4. Repeat with `--apply home-server`: expect shared values, `fd`, `,server-demo`, `poc_server`, and `server.conf`, but no laptop-only entries. New workspace, no overwrite.
5. In both workspaces inspect `git -C <workspace>/private-fixture log -1` and `git -C <workspace>/private-fixture remote -v`: one synthetic commit and **no remotes**. No real tools installed.
6. Automated: `python3 tests/private-profiles-poc.py` checks refusals, isolated composition, conflicting pins and non-overwrite. Requires Python 3.11+ and Git; shell validation also runs it in CI.
7. Remove only the printed disposable workspace directories after review. No cleanup of real machine config is needed.

## Next design step

A future, separately reviewed implementation may accept an **explicit authorised** GitHub repo URL and selected profile, request permission before any clone/update, and preview every tool, PATH entry and dotfile target. The public bootstrap must remain standalone. Never discover private repositories automatically or assume an employer-owned repo can be stored in a personal GitHub account. Keep SSH private keys, age identities and other credentials outside both public and optional private Git; use separately secured backups.

See [configuration layers](../architecture/private-configuration.md), [private overlay prototype](private-profiles.md) and [roadmap](../roadmap.md).
