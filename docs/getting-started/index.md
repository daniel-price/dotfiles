# Getting started

Only **Git acquisition and a one-time public HTTPS clone** are implemented.
The remaining development environment setup is still a read-only scaffold.

## Fresh machine: one-file bootstrap

Prerequisites: Bash 3.2+ and curl; Git and GitHub SSH keys are **not** required.
Supported hosts are macOS and Debian/Ubuntu-derived Linux (including Pop!_OS).

```sh
curl -fsSLo dotfiles-get-started.sh https://raw.githubusercontent.com/daniel-price/dotfiles/main/get-started.sh && bash dotfiles-get-started.sh
```

Review the downloaded script before running it. It uses the system's Git if
available; otherwise it asks before installing Git using apt on Linux or
requesting Apple's Command Line Tools on macOS. It then asks before one HTTPS
clone into `~/.dotfiles`. On macOS, complete the installation dialog and rerun.

A matching checkout is **not** updated or cloned again. Files, symlinks and
checkouts with unexpected remotes at the destination are never overwritten.
Refusals and noninteractive input do not authorise changes. Do not use
`curl ... | bash` or pipe `yes` to this script.

## Inspect the checkout scaffold

```sh
bash ~/.dotfiles/bootstrap.sh --help
bash ~/.dotfiles/bootstrap.sh
bash ~/.dotfiles/update.sh
bash ~/.dotfiles/tests/run.sh
```

**Expected:** both checkout scripts still identify the OS, list unimplemented
steps and report `No changes made.` The scaffold tests use temporary fixtures
and should finish with `All scaffold checks passed.`

The scripts are read-only today but a later version will request confirmation
before each change. Read the code and documentation for the version you check
out before running it on a live machine.

## New machine: intended future flow

1. Download and inspect the standalone `get-started.sh`, then run it interactively.
2. Ensure Git only if missing, with explicit approval.
3. Clone this public personal repository once (implemented in stage zero).
4. Install mise after approval; provision tools and apply reviewed dotfiles.
5. Optionally opt into an authorised private configuration source on selected
   machines. The public setup must not depend on it.
6. Restore authorised encrypted settings using a **separately recovered** age
   identity; keep machine-specific SSH credentials local.
7. Re-run without unnecessary changes; upgrades remain an explicit action.

**Not implemented:** automatic delegation to the main bootstrap, SSH
registration, mise deployment, private-layer integration and encrypted restore
steps. Git installation and the initial clone are the only implemented actions. No private repositories should be discovered or cloned automatically;
see [the private-profile guide](../guides/private-profiles.md).

## Existing machine: intended future flow

The eventual `update.sh` will check the remote, guard dirty/diverged state,
fast-forward only when approved, and preview each configuration change before
applying it. Today it only reports the detected OS.

## Documentation preview

From a repository checkout:

```sh
python3 -m pip install zensical
zensical serve
```

This serves the Markdown documentation locally. It does **not** initialise the
development environment. See [the roadmap](../roadmap.md) for upcoming work.
