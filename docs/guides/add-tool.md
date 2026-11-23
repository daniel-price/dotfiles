# Add or change a tool

- Base CLI tools: [setup/base-tools.toml](../../setup/base-tools.toml).
- OS packages: `[bootstrap.packages]` in [setup/mise.toml](../../setup/mise.toml).
- Optional tools: `config.<env>.toml`.

```sh
bash bin/,bootstrap --no-update
```

Authenticate GitHub CLI separately with `gh auth login`.
