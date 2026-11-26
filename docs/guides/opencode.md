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

Also supports `OPENAI_API_KEY` and `OPENROUTER_API_KEY`. Authentication inside the container is temporary.

## Isolation

- Only the selected repository is mounted read/write; host home and credentials are not mounted.
- The agent can modify or transmit any file in that repository and use explicitly passed credentials.
- Outbound networking is enabled. Use a separate VM for untrusted or unattended work.
- Image versions are pinned by tag, not digest.

[CLI reference](cli.md#opencode-sandbox)

## Profile images

An explicitly selected profile may call the Base launcher with `--profile-dir DIR`.
The profile's `containers/opencode/Containerfile` extends the shared local image
using `ARG OPENCODE_IMAGE` and `FROM ${OPENCODE_IMAGE}`. Review its build context
before approving the build. Base owns the upstream version and runtime isolation.
