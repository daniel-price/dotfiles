# OpenCode sandbox

Pop!_OS only. Select the `opencode` [mise module](mise-modules.md).

```sh
cd /path/to/personal-git-repo
opencode-sandbox --dry-run
opencode-sandbox
```

The launcher offers to install [Podman](podman.md) if missing.

## Credentials

```sh
opencode-sandbox --credential-env ANTHROPIC_API_KEY
```

Also supports `OPENAI_API_KEY` and `OPENROUTER_API_KEY`. Authentication inside the container is temporary.

## Isolation

- Only the selected repository is mounted read/write; host home and credentials are not mounted.
- The agent can modify or transmit any file in that repository and use explicitly passed credentials.
- Outbound networking is enabled. Use a separate VM for untrusted or unattended work.
- Image versions are pinned by tag, not digest.

[CLI reference](cli.md#opencode-sandbox)
