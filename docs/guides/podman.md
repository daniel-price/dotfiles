# Podman

Optional Linux runtime, declared in [containers/podman/mise.toml](../../containers/podman/mise.toml).

```sh
bash setup/setup-podman.sh
bash setup/setup-podman.sh --apply
podman info --format '{{.Host.Security.Rootless}}'
```

Run as your normal user; the last command must return `true`. Do not use `sudo podman`. Cleanup does not remove this shared runtime.
