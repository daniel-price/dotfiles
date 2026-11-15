# dotfiles

Personal development environment for macOS and Debian/Ubuntu-derived Linux,
primarily Pop!_OS. Bash coordinates setup; mise is the intended owner of both
development tools and declarative dotfile deployment, with apt for Linux system
packages and Homebrew for macOS packages only.

## Current status

**Initial scaffolding only.** Both entry points detect the OS and explain what
remains unimplemented. They make no changes and need neither Git nor mise to run
from an existing checkout. A successful exit means inspection completed, not that
the machine has been configured.

Package installation, SSH configuration, mise installation, cloning, Git
synchronisation, mise dotfile deployment, encrypted-secret restoration, OS
settings and bootstrap delegation to `update.sh` are all deferred. No existing
dotfiles have been migrated.

## Try the scaffold

From a checkout, using Bash 3.2 or newer and standard Unix utilities:

```sh
bash bootstrap.sh --help
bash bootstrap.sh
bash update.sh
bash tests/run.sh
```

The scripts work from other working directories too: pass their full paths.
Unsupported systems exit with a clear error. Linux detection reads OS metadata;
it does not assume that the presence of apt makes a distribution supported.

`bootstrap.sh` currently requires its sibling `scripts/lib/` files. A standalone
fresh-machine entry path will be implemented separately; do not pipe this script
from a URL into Bash.

## Layout

| Path | Purpose |
| --- | --- |
| `bootstrap.sh` | Future fresh-machine entry point; currently inspection only |
| `update.sh` | Future recurring synchronisation; currently inspection only |
| `scripts/lib/common.sh` | Output, errors and reusable interactive confirmation |
| `scripts/lib/os.sh` | Read-only platform detection |
| `.config/mise/config.toml` | Valid, empty tools table; no selected tools or tasks |
| `.config/{nvim,zellij,ghostty}/` | Directory markers only, awaiting explicit migration |
| `tests/run.sh` | Bash syntax, OS fixtures, confirmation refusal and smoke checks |
| `docs/architecture.md` | Ownership, safety, mise dotfiles and secret-storage design |
| `docs/roadmap.md` | Small follow-up changes with acceptance checks |

The `.gitkeep` files are inert directory markers, not application configuration.
Do not deploy the entire `.config` tree or replace live directories with these
empty directories. The mise file is also not installed or linked by these scripts.

## Safety contract

- Inspect current state first; skip anything already in the desired state.
- Ask before **each** operation that could modify anything, including downloads,
  Git fetches, privileged commands, backups and symlinks.
- The confirmation helper accepts explicit `y` or `yes` (any case) from an
  interactive terminal. Blank input, other answers, EOF and piped input decline.
- Show the exact proposed action and affected paths. Existing configuration
  conflicts must be resolved explicitly; never overwrite them silently.
- Installing missing software and upgrading existing software are separate
  operations. A routine update must not upgrade installed software implicitly.
- Never publish plaintext credentials or private decryption identities to this
  public repository. Machine-specific SSH keys remain local. Any future encrypted
  values or encrypted history require explicit review, key recovery and tests
  before Git publication; review every staged diff because `.gitignore` is not
  a secret scanner.

**Chosen direction (plan only):** use mise's native `[dotfiles]` deployment,
`mise dot apply`/`diff`, runtime management and age-backed secret features; do
not add chezmoi or bespoke symlink management. Keep the normal public checkout
separate from mise's Git-backed tracked-file history. Initially keep SSH keys
and other machine identities out of Git. Encrypted values in mise configuration
and encrypted tracked-file history are different mechanisms; the latter needs
a deliberately configured history origin (preferably private), **not** the
public checkout's default branch. See [architecture](docs/architecture.md).

No confirmation prompts are needed yet because the entry points have no
modifying operations. Local override files are ignored but are not loaded by the
scaffold. See the [architecture](docs/architecture.md) and
[roadmap](docs/roadmap.md) before adding behaviour.

## Validation

`bash tests/run.sh` requires only Bash and standard Unix utilities. It creates
temporary fixtures outside the checkout and removes them on exit. It performs no
network requests or installations and does not touch existing dotfiles.

Fixtures cover macOS, Debian, Ubuntu, Pop!_OS and another Ubuntu derivative, plus
unsupported and missing metadata cases. They simulate platform detection; they
do not replace testing on a real Mac and a disposable Pop!_OS machine.
