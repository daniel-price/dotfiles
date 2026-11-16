# Dotfiles handbook

This is the documentation for my personal development environment. The goal is
to make a new Pop!_OS or macOS machine feel familiar without having to remember
how everything was configured, while keeping the setup reviewable and safe.

**Status: minimal bootstrap working (November 2026).** Stage zero can install
Git if missing, clone the public checkout and, with separate approval, run
its read-only bootstrap. Mise, dotfiles and secrets setup remain unimplemented.

## What is this?

A public Git repository holding the source of my portable development setup,
small Bash entry points, future mise configuration and the documentation
explaining how it works. An optional, separately approved private source may
add non-public personal/work configuration, but it is not integrated yet.
Human-facing instructions live here; deeper technical
design and historical plans are [available separately](reference/index.md).

## What currently works?

| Capability | Status |
| --- | --- |
| OS detection and explicit yes/no helper | Implemented in the scaffold |
| Read-only `bootstrap.sh` and `update.sh` | Implemented |
| Temporary download, Git prerequisite, HTTPS clone and confirmed bootstrap handoff | Implemented as standalone stage zero |
| Dependency-free scaffold tests | Implemented |
| Installing tools and runtimes | Planned |
| Deploying Neovim, Zellij, Ghostty or shell settings | Planned |
| Encrypted secret restoration | Planned |
| Optional private configuration repository | Planned; not connected |
| Container/service configuration | Not yet designed |
| GitHub Pages publication | Proposed in this documentation PR |

`get-started.sh` only ensures Git and acquires the public checkout. An exit
code of zero from the checkout's `bootstrap.sh` still means **inspection
completed**, not that the machine has been configured.

## Start a new machine

Copy this into your terminal on macOS or Pop!_OS after
[reviewing the script](https://github.com/daniel-price/dotfiles/blob/main/get-started.sh):

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

The temporary download cleans up automatically. Git installation, checkout,
and running the checkout bootstrap each require explicit approval. Your
repository stays in `~/.dotfiles`; private configuration is never installed.

## How do I use it?

Start with [Getting started](getting-started/index.md), which shows what can
safely be run today and what cannot. For the reasoning behind choices, read
[Requirements](requirements.md) and [Architecture](architecture/index.md),
including [private configuration](architecture/private-configuration.md).
For unfinished functionality, see the [Roadmap](roadmap.md).

> Public repository: files under `docs/reference/` are public too, even when
> they are omitted from the main navigation. Never store secrets there.
