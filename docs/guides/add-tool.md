# Add or change a tool

**Status: partly implemented.** Bootstrap installs pinned mise and can provision
Neovim through `scripts/provision-tool.sh`. Other tools remain planned.

`scripts/provision-tool.sh` accepts one reviewed tool name at a time. Neovim is
currently mapped to `neovim@0.12.6`, with the same version declared in
`.config/mise/tools/mise.toml`. That directory is separate from the checkout
config so CI does not install machine tools. The script checks the installed state with
`mise install --dry-run-code`, asks before `mise install`, and skips an already
installed version. It does not upgrade tools.

1. Decide whether the tool belongs in mise or the OS package manager.
2. For a shared version, add a small tool declaration to
   `.config/mise/tools/mise.toml`; keep OS-specific packages in the correct
   apt/Homebrew boundary.
3. Review the package source, exact version and install behaviour.
4. Add an explicit mapping in `scripts/provision-tool.sh` only after testing it
   with an isolated HOME and fake mise commands.
5. Verify installed tools are skipped, declines make no change and upgrades stay
   a separate action.
6. Update the installed-tool inventory and this guide.

See [architecture](../architecture/index.md), the
[per-platform inventory](../architecture/platforms.md#installed-tool-inventory)
and the [roadmap](../roadmap.md).
