# OpenCode on Pop!_OS: rootless Podman sandbox

OpenCode is a coding agent with file and shell tools. Its built-in permission
prompts are **not OS isolation**. For personal development on Pop!_OS,
the reviewed default is **one disposable rootless Podman container per launch**.
For untrusted or unattended work, prefer a separate disposable VM.

The public bootstrap does **not** install the native OpenCode CLI through
mise, since that would make running the unsandboxed host agent too easy.
The entry point is `bin/opencode-sandbox`; the reviewed Zsh config adds
the checkout's `bin/` directory to PATH.

## Prerequisites (Pop!_OS / Ubuntu)

Podman is a shared, **optional system prerequisite**, declared once in
[`containers/podman/mise.toml`](../../containers/podman/mise.toml).
It is **not installed by the main machine bootstrap**. The launcher offers
to install it via mise/apt only when it is missing, with a preview and an
individual confirmation first. You can also inspect or install it explicitly:

```sh
bash scripts/setup/setup-podman.sh          # Read-only preview / rootless check
bash scripts/setup/setup-podman.sh --apply  # Ask before missing apt:podman install
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

From a checkout with the reviewed Zsh configuration active (or use
`bash ~/.dotfiles/bin/opencode-sandbox` directly):

```sh
cd /path/to/your/personal-git-repo
opencode-sandbox --dry-run    # Preview; no Podman calls or network
opencode-sandbox              # Confirm pull, build, then launch
```

On first use the launcher independently asks before **pulling the base image**,
**building the small local image** and **running the agent**. On subsequent
runs, it asks before launching but reuses the existing local image.
Noninteractive and piped approvals are rejected. You may select a different
repository with `--project /absolute/path/to/repository`.

See the [generated CLI reference](cli.md#opencode-sandbox) for the current launcher flags.

The selected path must be the root of a standard Git working tree with
its own real `.git/` directory. Linked worktrees, parent directories,
home directories, arbitrary mounts and running as root are refused.

### Isolation guarantees and limitations

The reviewed launcher runs with:

- A **single read/write bind mount**: the selected repo at `/workspace`
- No host home, `~/.ssh`, Git/cloud credentials, unrelated directories,
  or Docker/Podman socket mounts
- An **ephemeral** container home under `/tmp` with no persistent auth
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
token values in shell history or the repository. Interactive provider logins
inside the container disappear when the container exits.

Persistent OAuth/provider login would require a separately reviewed state
volume and is deliberately **not enabled**.

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
The existing `scripts/setup/cleanup.sh` only manages mise tools, not
Podman images. To remove the custom image after review:

```sh
podman image rm localhost/dotfiles-opencode-sandbox:2.3.0-r1
```

Podman and unrelated images remain untouched. If you previously installed
`opencode@2.3.0` on the host from an earlier PR, removing that manifest entry
does **not** uninstall it. Verify no other project depends on that shared
version before manually removing it.

References: [OpenCode security policy](https://github.com/anomalyco/opencode/security),
[OpenCode official image](https://opencode.ai/docs/),
[Podman installation](https://podman.io/docs/installation),
[Podman run reference](https://docs.podman.io/en/stable/markdown/podman-run.1.html).
