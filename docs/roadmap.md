# Incremental roadmap

Implement each row as a small, reviewable change. Split the macOS and Linux paths
or individual applications further when helpful. Validate modifying behaviour in
a disposable machine or isolated home before using it on a daily workstation.

| Order | Change | Independently testable acceptance check |
| --- | --- | --- |
| 1 | Establish the first operation's state check, precise prompt and truthful outcome reporting. | Already-correct state skips; decline and noninteractive input leave state untouched; failure is visible. |
| 2 | Ensure only missing Git, Zsh and curl prerequisites, separately for apt/Linux and Homebrew/macOS. | Each missing item needs consent; installed items are untouched; Linux never invokes Homebrew; no implicit upgrades. |
| 3 | Add guided machine-specific SSH key creation and public-key registration instructions. | Existing keys are preserved; all writes require consent; private material stays local; authentication can be checked without publication. |
| 4 | Install mise through a reviewed official method and a chosen supported version. | Existing installation is detected; decline leaves no downloads or files; a second run makes no unnecessary changes. |
| 5 | Complete bootstrap acquisition, clone the exact personal dotfiles remote, and delegate to update. | Fresh-machine flow has no missing sibling files; existing/conflicting paths are safe; declined clone or delegation is honoured. |
| 6 | Add guarded Git synchronisation to update. | Consent precedes fetch/pull; clean fast-forward succeeds; dirty, diverged or unexpected remotes fail without discarding work. Review newly fetched code before running it. |
| 7 | Declare and provision one runtime/tool at a time with mise; add required system packages separately. | Missing tool installs only with consent; existing tools are not upgraded implicitly; shared and OS-specific declarations are tested. |
| 8 | Validate mise `[dotfiles]` with one disposable file, then migrate one explicitly approved configuration at a time. | Same symlink is skipped; conflicts cannot be overwritten silently; each write needs consent; markers are excluded; no private values enter Git. |
| 9 | Add one optional OS setting at a time. | Detect existing value; show old/new values; decline is harmless; repeated application is idempotent on the target OS. |
| 10 | Add an explicit upgrade operation and complete the change summary. | Routine update leaves installed versions alone; an upgrade lists exactly what will change and asks before each modifying operation. |

## Architecture decision: mise-only dotfiles

Use mise with a small Bash bootstrap/update layer. Do not add chezmoi, SOPS,
or an independent Bash symlink manager for ordinary dotfile deployment.

Revise the intended scope of steps 8–10 below as follows; make each a separate,
manual-testable PR before implementing it on a real home directory:

1. **Mise-managed deployment**: add repo-level `mise.toml` and explicit
   `[dotfiles]` entries. Confirm read-only preview and per-target approval in
   an isolated HOME, including already-correct state, conflicting files and
   symlinks, refusal, idempotence and rollback. Do not link marker directories.
2. **Encryption prototype**: independently validate age-encrypted mise
   environment values and encrypted whole-file tracking. Use fake credentials,
   test a clean first encrypted commit, restore on a second machine, and test
   missing keys/refusal. Never publish a real secret or recovery identity.
3. **Separate history origin**: if tracked-file sync is useful, select an
   explicit, preferably private Git origin for mise's history and review its
   initial contents before pushing. Do not confuse this with the public
   checkout or enable watchers/automatic sync by default. Keep per-machine
   SSH authentication keys local.
4. **OS settings and upgrades**: retain the existing one-setting-at-a-time
   and explicit-upgrade milestones, with the same per-operation consent.

Before step 8, review source files individually for platform paths, private
values, obsolete tools and dependencies on files outside version control. Do not
copy an existing private configuration repository wholesale. Migration always
needs separate, explicit approval for the files being moved.

Keep validation alongside each feature: add fixtures for new edge cases and
tests that check visible behaviour. Add continuous validation on Linux and macOS
when useful; avoid installing a large test framework for the initial scripts.
