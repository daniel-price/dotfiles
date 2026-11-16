# Dotfiles handbook

This is the documentation for my personal development environment. The goal is
to make a new Pop!_OS or macOS machine feel familiar without having to remember
how everything was configured, while keeping the setup reviewable and safe.

**Status: one-managed-tool bootstrap with opt-in shell activation (November
2026).** Stage zero can install Git if missing, clone the public checkout and,
with separate approval, run its bootstrap. That bootstrap installs missing
`zsh`, `curl`, pinned mise and Neovim `0.12.6`. Separate opt-in scripts can
deploy a reviewed zsh startup file or one selected private directory; full
profile layering and secrets remain unimplemented.

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
| Install only missing `zsh` and `curl` with individual approval | Implemented |
| Install verified mise `v2026.11.9` with separate download and execution approval | Implemented |
| Provision Neovim `0.12.6` with mise and per-tool confirmation | Implemented |
| Opt-in deployment of a reviewed zsh startup file via mise | Implemented |
| Read-only `scripts/update.sh` | Implemented |
| Temporary download, Git prerequisite, HTTPS clone and confirmed bootstrap handoff | Implemented as standalone stage zero |
| Dependency-free scaffold tests | Implemented |
| Opt-in shell formatting/lint hooks and pinned development tools | Implemented; see [development](guides/development.md) |
| Installing further tools and runtimes | Planned |
| Deploying Zellij, Ghostty or broader shell settings | Planned |
| One-target private config directory overlay | Implemented; explicit opt-in only |
| Encrypted secret restoration | Planned |
| Full private configuration profiles and precedence | Planned; not connected |
| Container/service configuration | Not yet designed |
| GitHub Pages publication | Proposed in this documentation PR |

`get-started.sh` ensures Git and acquires the public checkout. The checkout
bootstrap then checks `zsh`, `curl`, mise and Neovim. Shell activation is a
separate opt-in step; an exit code of zero does not mean the machine has an
activated shell, other configured tools, deployed dotfiles or restored secrets.

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
