# Getting started

The project is **not an installer yet**. Use the commands below to inspect its
read-only scaffold; do not rely on them to configure a workstation.

## Inspect a checkout

Prerequisites: Git and Bash 3.2+; supported hosts are macOS and Pop!_OS or
another Debian/Ubuntu-derived Linux system.

```sh
git clone https://github.com/daniel-price/dotfiles.git
cd dotfiles
bash bootstrap.sh --help
bash bootstrap.sh
bash update.sh
bash tests/run.sh
```

**Expected today:** both scripts identify the OS, say which setup steps are
unimplemented and report `No changes made.` The tests use temporary fixtures
and should finish with `All scaffold checks passed.`

The scripts are read-only today but a later version will request confirmation
before each change. Read the code and documentation for the version you check
out before running it on a live machine.

## New machine: intended future flow

1. Acquire the small bootstrap entry point using a documented safe method.
2. Ensure Git and minimal prerequisites only after explicit approval.
3. Clone this public personal repository once.
4. Install mise after approval; provision tools and apply reviewed dotfiles.
5. Restore authorised encrypted settings using a **separately recovered** age
   identity; keep machine-specific SSH credentials local.
6. Re-run without unnecessary changes; upgrades remain an explicit action.

**Not implemented:** the standalone download, package installation, SSH
registration, mise deployment and encrypted restore steps.

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
