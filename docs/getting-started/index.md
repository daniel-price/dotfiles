# Getting started

The one-command installer ensures Git, acquires the public repository and
**offers to run its bootstrap with a separate confirmation**. The full
development-environment setup remains read-only scaffolding.

## Fresh machine: one-file bootstrap

Prerequisites: Bash 3.2+ and curl; Git and GitHub SSH keys are **not** required.
Bash is included on standard macOS and Pop!_OS installations, but not every
minimal Linux image. Supported hosts are macOS and Debian/Ubuntu-derived Linux
(including Pop!_OS).

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

**Copy the whole code block above into a terminal.** It downloads only
`get-started.sh` into a temporary directory, executes it after the download
finishes, and **deletes the temporary directory automatically** on exit or
ordinary failure. No downloaded script remains in your current directory.
[Read the script on GitHub](https://github.com/daniel-price/dotfiles/blob/main/get-started.sh)
before running downloaded code.

The script checks Git, asking before installation if needed (apt on Linux or
Apple Command Line Tools on macOS). It asks separately before an HTTPS clone
into `~/.dotfiles`, then **asks a third time before running** the checkout's
`scripts/bootstrap.sh`. It runs bootstrap from the repository directory without
changing your terminal's working directory.

On macOS, complete the Command Line Tools installer and rerun if Git was
missing. An existing matching checkout is reused without fetching or
updating it. Existing conflicting destinations are never overwritten.
Declining any prompt skips that operation.

The current bootstrap is `scripts/bootstrap.sh`. If a reused checkout still
has the earlier root-level `bootstrap.sh`, the standalone entry point can run
that version after the same separate approval; it does not update the checkout.

**Do not use `curl ... | bash`.** It interferes with the interactive
confirmation flow and can execute a partially downloaded script. The
temporary-file command downloads everything first.

## Inspect the checkout scaffold

After approving the clone, the script offers to run the bootstrap.
To inspect or rerun it later:

```sh
bash ~/.dotfiles/scripts/bootstrap.sh --help
bash ~/.dotfiles/scripts/bootstrap.sh
bash ~/.dotfiles/scripts/update.sh
bash ~/.dotfiles/tests/run.sh
```

**Expected:** both checkout scripts still identify the OS, list unimplemented
steps and report `No changes made.` The scaffold tests use temporary fixtures
and should finish with `All scaffold checks passed.`

The scripts are read-only today but a later version will request confirmation
before each change. Read the code and documentation for the version you check
out before running it on a live machine.

## New machine: intended future flow

1. Download the standalone `get-started.sh` to a temporary directory and
   run it interactively; the wrapper automatically cleans up.
2. Ensure Git only if missing, with explicit approval.
3. Clone the public repository once and separately approve its bootstrap
   (implemented in stage zero).
4. Install mise after approval; provision tools and apply reviewed dotfiles.
5. Optionally opt into an authorised private configuration source on selected
   machines. The public setup must not depend on it.
6. Restore authorised encrypted settings using a **separately recovered** age
   identity; keep machine-specific SSH credentials local.
7. Re-run without unnecessary changes; upgrades remain an explicit action.

**Not implemented:** SSH registration, mise deployment, private-layer
integration and encrypted restore. Git installation, the initial clone and
a confirmed handoff to the read-only checkout bootstrap are implemented.
No private repositories should be discovered or cloned automatically;
see [the private-profile guide](../guides/private-profiles.md).

## Existing machine: intended future flow

The eventual `scripts/update.sh` will check the remote, guard dirty/diverged state,
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
