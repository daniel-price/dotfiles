# Add or change a tool

- Base CLI tools: [src/home/.config/mise/base-tools.toml](../../src/home/.config/mise/base-tools.toml).
- OS packages: `[bootstrap.packages]` in [src/mise.toml](../../src/mise.toml).
- Optional tools: `config.<env>.toml`.

```sh
bash src/bin/,bootstrap --no-update
```

Authenticate GitHub CLI separately with `gh auth login`.
