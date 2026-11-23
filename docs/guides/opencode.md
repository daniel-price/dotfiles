# OpenCode on Pop!_OS: rootless Podman sandbox

OpenCode is a coding agent with file and shell tools. Its built-in permission
prompts are **not OS isolation**. For personal development on Pop!_OS,
the reviewed default is **one disposable rootless Podman container per launch**.
The container is disposable, but project-scoped OpenCode session data persists
in a rootless Podman named volume. For untrusted or unattended work, prefer a separate disposable VM.

**Only the rootless Podman sandbox is supported.** OpenCode is not installed
on the host through mise. Select the `opencode` mise environment on your
personal laptop or home server; it adds
`~/.dotfiles/modules/opencode/bin` to `PATH` and exposes
`opencode-sandbox`. Base and the `work` environment do not expose this
launcher. Selecting the environment does not install Podman or pull an image.
See [machine modules](mise-modules.md) for per-device selection.

## Prerequisites (Pop!_OS / Ubuntu)

Podman is a shared, **optional system prerequisite**, declared once in
[`containers/podman/mise.toml`](../../containers/podman/mise.toml).
It is **not installed by the main machine bootstrap**. The launcher offers
to install it via mise/apt only when it is missing, with a preview and an
individual confirmation first. You can also inspect or install it explicitly:

```sh
bash setup/setup-podman.sh          # Read-only preview / rootless check
bash setup/setup-podman.sh --apply  # Ask before missing apt:podman install
podman info --format '{{.Host.Security.Rootless}}'
```

The final command must return `true` as your normal user. Never use
`sudo podman`; if rootless configuration is broken, the setup refuses to
proceed rather than silently changing system security settings. See the
[shared Podman prerequisite guide](podman.md) for details and future workloads.

The launcher pins the official published OpenCode image
`ghcr.io/anomalyco/opencode:2.3.0`. The reviewed
[Containerfile](../../containers/opencode/Containerfile) adds Git and
CA certificates, tagging the result
`localhost/dotfiles-opencode-sandbox:2.3.0-r1`.
The upstream tag is **not pinned by digest**; this is version pinning,
not immutable image verification. Building can download Alpine packages.
Neither the agent nor the image is automatically upgraded.

## Launch for one selected personal Git repository

From a new mise-activated Zsh session with the `opencode` environment
selected (or invoke `bash ~/.dotfiles/modules/opencode/bin/opencode-sandbox`
explicitly):

```sh
cd /path/to/your/personal-git-repo
opencode-sandbox --dry-run    # Preview; no Podman calls or network
opencode-sandbox              # Confirm pull, build, then launch
opencode-sandbox -c           # Continue the current project's latest session
opencode-sandbox -s ses_...   # Resume a saved session ID
```

On first use the launcher independently asks before **pulling the base image**,
**building the small local image** and **running the agent**. On subsequent
runs, it asks before launching but reuses the existing local image.
Noninteractive and piped approvals are rejected. You may select a different
repository with `--project /absolute/path/to/repository`.
The `-s`/`--session ID` and `-c`/`--continue` options are explicit
OpenCode pass-throughs and cannot be combined; arbitrary Podman/OpenCode flags
remain disallowed.

Persistent state uses a rootless Podman named volume derived from the canonical
Git checkout path (`dotfiles-opencode-<hash>`), mounted at `/state` with
`XDG_DATA_HOME=/state`. Reopening the same checkout reuses sessions; a different
path gets a different volume. **Previous ephemeral sandbox sessions cannot be
recovered**, and host OpenCode sessions are never imported.

See the [generated CLI reference](cli.md#opencode-sandbox) for the current launcher flags.

The selected path must be the root of a standard Git working tree with
its own real `.git/` directory. Linked worktrees, parent directories,
home directories, arbitrary mounts and running as root are refused.

### Isolation guarantees and limitations

The reviewed launcher runs with:

- A **single host-directory bind mount**: the selected repo at `/workspace` (read/write)
- A separate per-project **Podman named volume** at `/state` for persistent OpenCode data
- No host home, `~/.ssh`, Git/cloud credentials, unrelated directories,
  or Docker/Podman socket mounts
- An **ephemeral** container home/config/cache under `/tmp`, with sessions and
  potentially saved provider credentials persisting in the named volume
- Rootless Podman with mapped user UID/GID, all Linux capabilities dropped,
  `no-new-privileges`, read-only image filesystem, memory and PID limits
- No published server ports and no arbitrary Podman/agent command flags

**Important limitations:** the default rootless container network still
permits outbound connections. The agent can read, modify or delete any
tracked **or ignored** file in the mounted repository, use the network,
and transmit project contents to services/providers. It could also read
secrets placed inside that repository. Do not put unrelated repositories
or sensitive credentials under the mounted tree. Inspect `git diff`
before accepting changes. Containers are not a VM-strength security
boundary, and rootless mode does not eliminate all kernel risks.

### Explicit provider credentials

No API credential is passed by default. If you already have a narrowly scoped
provider key in your environment, allowlist its **variable name**:

```sh
opencode-sandbox --credential-env ANTHROPIC_API_KEY
```

Supported names: `ANTHROPIC_API_KEY`, `OPENAI_API_KEY` and
`OPENROUTER_API_KEY`. The launcher never prints their values or embeds
literal values in Podman's command arguments; Podman forwards the selected
environment variable **to the agent**, so the agent may use or exfiltrate it.
Prefer revocable keys with limited spending and permissions. Do not put
token values in shell history or the repository. Interactive provider logins may persist if OpenCode stores them in its data directory.

**Persistence security trade-off:** session transcripts, snapshots and stored
provider credentials (including API keys or OAuth tokens) may remain in the
named volume after the container exits. This is not an encryption boundary.
No host credentials are mounted by default. Use trusted code, limit provider
permissions and remove state you no longer need.

### Developer dependencies

The base image is intentionally minimal, with OpenCode, Git and basic Alpine
utilities. Node, Python, Docker and other host developer runtimes are **not**
inherited. Add them in a reviewed Containerfile change and bump the local
image revision if a particular workflow needs them. Do not mount your
host development directories or container socket as a workaround.

No background service, browser server or localhost port is exposed by this
launcher. Use a **disposable VM** for high-autonomy, untrusted or privileged
work, and an expressly approved environment for employer resources.

## Updating and cleanup

```sh
opencode-sandbox --dry-run
podman images
```

The launcher reuses the local image; version changes are deliberate.
The existing `setup/cleanup.sh` manages mise tools, not
Podman images or session volumes. Removing the image does not remove state.
To remove the custom image after review:

```sh
podman image rm localhost/dotfiles-opencode-sandbox:2.3.0-r1
```

List sandbox state volumes with `podman volume ls --filter name=dotfiles-opencode-`.
Check the exact volume name using `opencode-sandbox --dry-run` before running
`podman volume rm VOLUME_NAME`; **this permanently deletes session history
and saved credentials**. Do not remove volumes you still need.

Podman and unrelated images remain untouched. If you previously installed
`opencode@2.3.0` on the host from an earlier PR, removing that manifest entry
does **not** uninstall it. Verify no other project depends on that shared
version before manually removing it.

References: [OpenCode security policy](https://github.com/anomalyco/opencode/security),
[OpenCode official image](https://opencode.ai/docs/),
[Podman installation](https://podman.io/docs/installation),
[Podman run reference](https://docs.podman.io/en/stable/markdown/podman-run.1.html).
