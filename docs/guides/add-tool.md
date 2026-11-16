# Add or change a tool

**Status: planned.** Bootstrap can install mise itself, but the committed
`.config/mise/config.toml` currently has only an empty `[tools]` table. Tool
installation is not yet implemented.

1. Decide whether the tool belongs in mise or the OS package manager.
2. For shared versions, propose a small mise declaration in a PR; for
   OS-specific packages, keep the correct apt/Homebrew boundary.
3. Review the package source and the exact version/install behaviour.
4. Test detection and explicit consent in an isolated HOME/VM before a live run.
5. Verify installed tools are skipped, and upgrades are separate from installs.
6. Update this documentation with the implemented command once it exists.

See [architecture](../architecture/index.md) and the
[roadmap](../roadmap.md).
