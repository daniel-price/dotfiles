# Use an optional private configuration profile

**Status: narrow single-directory prototype implemented.** This guide covers
the original helper for symlinking one already-present directory to one target.
For real independent private Git repositories, approved profile selection,
tool pins and Bash/Zsh/app configuration, use the
[profile-repositories POC](private-profiles-poc.md) instead.

The public setup never needs private access. Only run this script on a machine
and for a source you are explicitly authorised to use. Never put a private
remote, path, credential or file content in this public repository, CI or the
generated site.

## Prerequisites

- Bash 3.2+ and a working `mise` installation.
- A selected source directory that already exists locally as a real directory.
- A target parent directory that already exists, such as `~/.config`.
- An informed decision about work versus personal storage. Work-owned files
  require employer-approved storage and devices.

## Deploy one selected directory

Set the paths in your shell only; do not commit them:

```sh
PRIVATE_SOURCE='/absolute/path/to/authorised/source'
PRIVATE_TARGET="$HOME/.config/nvim"
```

Review the preview and then answer the confirmation prompt:

```sh
bash ~/.dotfiles/scripts/setup/apply-private-overlay.sh \
  --source "$PRIVATE_SOURCE" \
  --target "$PRIVATE_TARGET"
```

Expected: the script calls `mise dot diff` and `mise dot apply --dry-run`,
shows the proposed symlink, then asks before `mise dot apply`. The generated
mise configuration lives in a temporary directory and is trusted only for the
invoking process; no persistent trust setting is changed.

A repeat run detects that the target already points at the selected source and
exits without invoking mise or prompting.

## Safety behaviour

The script refuses to continue when:

- the source is missing, is a symlink, is not a directory or contains control
  characters in its path;
- the source Git checkout is dirty, diverged from upstream, or behind upstream;
- the target parent is missing or is not a regular directory;
- the target is a real file or directory, or is a symlink to a different place.

It never uses `mise dot apply --force`, deletes a conflicting target, fetches
updates or chooses a source on your behalf. Resolve conflicts manually and
rerun. Declining the confirmation leaves the target unchanged.

## Testing

Automated checks use synthetic Git repositories and fake mise commands. They
cover refusal, preview, approval, repeat application, real-path conflicts,
different symlinks, dirty checkouts and divergence. They do not use real
private repositories or credentials. See `tests/tool-overlay-interactive.py`.

For a manual test, create two disposable directories with synthetic files and
use them as `PRIVATE_SOURCE` and a target under a temporary `HOME`. After the
test, remove the created symlink and temporary directories. Do not test against
a live editor configuration until you have reviewed the preview.

See [configuration layers](../architecture/private-configuration.md),
[Secrets](../architecture/secrets.md) and
[ADR-0003](../decisions/0003-private-config-layers.md).
