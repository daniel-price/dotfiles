# Dotfiles handbook

This is the documentation for my personal development environment. The goal is
to make a new Pop!_OS or macOS machine feel familiar without having to remember
how everything was configured, while keeping the setup reviewable and safe.

**Status: scaffold only (November 2026).** Nothing has been installed or
restored by this repository yet. The existing scripts detect the platform,
describe intended behaviour and exit without changing the machine.

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
| Dependency-free scaffold tests | Implemented |
| Installing tools and runtimes | Planned |
| Deploying Neovim, Zellij, Ghostty or shell settings | Planned |
| Encrypted secret restoration | Planned |
| Optional private configuration repository | Planned; not connected |
| Container/service configuration | Not yet designed |
| GitHub Pages publication | Proposed in this documentation PR |

An exit code of zero from the current bootstrap means **inspection completed**,
not that setup was successful.

## How do I use it?

Start with [Getting started](getting-started/index.md), which shows what can
safely be run today and what cannot. For the reasoning behind choices, read
[Requirements](requirements.md) and [Architecture](architecture/index.md),
including [private configuration](architecture/private-configuration.md).
For unfinished functionality, see the [Roadmap](roadmap.md).

> Public repository: files under `docs/reference/` are public too, even when
> they are omitted from the main navigation. Never store secrets there.
