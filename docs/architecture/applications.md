# Applications and containers

**Direction, not implementation:** choose the simplest safe way to manage each
category of software. Containerisation should be deliberate rather than
automatic.

| Workload | Default direction |
| --- | --- |
| Developer runtimes and CLI tools | mise where suitable |
| Essential OS tools and desktop applications | apt (Pop!_OS) or Homebrew (macOS) |
| Long-running/self-hosted services | Evaluate containers for isolation, upgrades and persistence |
| Apps needing direct hardware/desktop integration | Prefer native packaging when containers add friction |

For services such as Jellyfin, Radarr and VPN-related components, future
decisions should document the container runtime, network isolation, volume
ownership, secrets injection, restart behaviour, backups and update strategy.
The choice between Docker/Compose and alternatives is **not yet accepted**.

No container definitions or services are currently installed by this repo.
Before adding them, create a focused decision record and a manual test plan.
