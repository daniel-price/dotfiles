# Applications and containers

**Direction, not implementation:** choose the simplest safe way to manage each
category of software. Containerisation should be deliberate rather than
automatic.

| Workload | Default direction |
| --- | --- |
| Developer runtimes and CLI tools | mise where suitable |
| Coding agents that execute commands | Rootless per-project container by default on Pop!_OS; separate VM for higher-risk work |
| Essential OS tools and desktop applications | apt (Pop!_OS) or Homebrew (macOS) |
| Long-running/self-hosted services | Evaluate containers for isolation, upgrades and persistence |
| Apps needing direct hardware/desktop integration | Prefer native packaging when containers add friction |

For services such as Jellyfin, Radarr and VPN-related components, future
decisions should document the container runtime, network isolation, volume
ownership, secrets injection, restart behaviour, backups and update strategy.
The choice between Docker/Compose and alternatives is **not yet accepted**.

A reviewed **rootless OpenCode CLI container launcher** is implemented as an
explicit personal-workflow option, not a daemon or background service. It
uses the [shared optional Podman prerequisite](../guides/podman.md) through
an explicit per-workload confirmation and gives the agent write access
to a single selected Git checkout; see the [security guide](../guides/opencode.md).
No long-running service containers are installed by this repo. Before adding
one, create a focused decision record and manual test plan.
