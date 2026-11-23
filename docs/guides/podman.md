# Optional Podman prerequisite for container workloads

Podman is a **shared runtime dependency**, not a default machine tool.
The main bootstrap does not install Podman just because the dotfiles repository
contains a container recipe.

## Declarative source of truth

- `containers/podman/mise.toml` declares only the Linux system package
  `"apt:podman" = { os = "linux" }` using mise's native package management.
- `setup/setup-podman.sh` is the shared, small safety wrapper: isolate
  that manifest, preview changes, obtain one explicit terminal confirmation,
  delegate installation to mise, and verify **rootless** operation.
- Every workload reuses that same setup command. A service's own image,
  configuration, volumes, network and lifecycle live in a separate reviewed
  workload directory. Do not duplicate the Podman apt package declaration
  in every application or add it to the general machine bootstrap.

The wrapper uses `MISE_GLOBAL_CONFIG_FILE` and `mise -C /` so the current
project, checkout development tools and the normal machine manifest do not
become install targets. It does not install mise itself: use the existing
reviewed machine bootstrap to install mise first if it is absent.

## Usage on Pop!_OS

```sh
bash setup/setup-podman.sh            # Preview missing apt package
bash setup/setup-podman.sh --apply    # Ask before installing it
podman info --format '{{.Host.Security.Rootless}}'
```

Run these **as your normal user**, never with `sudo`. The last command
must return `true`. If the package exists, setup skips installation
and checks rootless mode; it does not upgrade the package.

If Podman is missing, `--apply` first asks mise to preview the declared
package. It then prompts for confirmation (default **No**). Only after
approval does mise use apt with the necessary system privileges. Declining
does nothing. A noninteractive run cannot approve installation.

Podman's Linux user namespaces, `uidmap` tooling and
`/etc/subuid` / `/etc/subgid` entries may need host-specific configuration.
If rootless mode does not work, the script fails closed with guidance;
it **never edits these files, enables daemons or switches to rootful mode**.

## Reuse in applications and services

**OpenCode:** `opencode-sandbox` runs in a rootless container and, only when
Podman is missing, calls `setup/setup-podman.sh --apply` before
proceeding. Its mount, token and image policies are defined separately;
see the [OpenCode guide](opencode.md).

**Future Radarr or other long-running media services:** Reuse the **same
Podman prerequisite**, but define persistent volumes, non-root ownership,
network exposure, health checks, updates and a user-level systemd
**Quadlet** or an explicitly reviewed Compose configuration in that
service's own directory. A one-shot agent launcher is not a substitute
for service lifecycle management.

**Future OpenClaw or other autonomous agents:** Reuse Podman setup but
choose **stricter per-agent isolation**: workspace and secret scoping,
network controls and, for high-risk or unattended activity, a disposable VM.
Containerisation alone does not prevent outbound access or make an agent
trustworthy. Do not reuse OpenCode's writable-project mount or token policy
without a separate review.

These are **patterns, not implementations**: no Radarr or OpenClaw
containers, services, credentials, ports or volumes are created here.

## Cleanup and ownership

`bash setup/cleanup.sh` continues to manage only eligible mise
**tool versions** and reviewed dotfiles, not system packages.
An apt-installed Podman runtime may be shared by multiple workloads.
Never uninstall Podman or remove its containers, images or volumes
as a side effect of uninstalling one app. Before removing a shared
runtime, enumerate every consumer and ask separately.

References: [mise bootstrap packages](https://mise.jdx.dev/bootstrap/packages/),
[mise apt package integration](https://mise.jdx.dev/bootstrap/packages/apt.html),
[Podman installation](https://podman.io/docs/installation),
[Podman rootless documentation](https://github.com/containers/podman/blob/main/docs/tutorials/rootless_tutorial.md).
