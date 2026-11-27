# OpenCode sandbox

Pop!_OS only. Select the `opencode` [mise module](mise-modules.md).

```sh
cd /path/to/personal-git-repo
,opencode --dry-run
,opencode
```

The launcher offers to install [Podman](podman.md) if missing.

## Credentials

```sh
,opencode --credential-env ANTHROPIC_API_KEY
```

Also supports `OPENAI_API_KEY` and `OPENROUTER_API_KEY`. Authentication saved by OpenCode inside the container persists in its private data volume; forwarded environment variables are not written there by the launcher.

## Resume sessions

```sh
,opencode -c
,opencode -s ses_YOUR_SESSION_ID
```

Use the same project and profile for each launch. Session data is stored in a
dedicated rootless Podman named volume, not in Git or the host home.
Sessions from before this feature cannot be recovered from removed containers.
The volume is reported during `--dry-run`. To permanently delete its sessions
and saved authentication, exit OpenCode and explicitly run
`podman volume rm VOLUME_NAME` with that reported name. Bootstrap and cleanup
do not remove the volume.

## Isolation

- Only the selected repository and its dedicated OpenCode data volume are mounted read/write; host home and credentials are not mounted.
- The agent can modify or transmit any file in that repository and use explicitly passed credentials.
- Outbound networking is enabled. Use a separate VM for untrusted or unattended work.
- Image versions are pinned by tag, not digest.

[CLI reference](cli.md#opencode-sandbox)

## Profile images

An explicitly selected profile may call the Base launcher with `--profile-dir DIR`.
The profile's `containers/opencode/Containerfile` extends the shared local image
using `ARG OPENCODE_IMAGE` and `FROM ${OPENCODE_IMAGE}`. Review its build context
before approving the build. Base owns the upstream version and runtime isolation.
