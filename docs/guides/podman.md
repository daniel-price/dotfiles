# Podman

Optional Linux runtime, declared in [src/modules/podman/mise.toml](../../src/modules/podman/mise.toml).

```sh
bash src/modules/podman/setup-podman.sh
bash src/modules/podman/setup-podman.sh --apply
podman info --format '{{.Host.Security.Rootless}}'
```

Run as your normal user; the last command must return `true`. Do not use `sudo podman`. Cleanup does not remove this shared runtime.
