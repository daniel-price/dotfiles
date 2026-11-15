# Manage a dotfile

**Status: planned.** Mise native dotfile deployment is the chosen direction,
but there are no configured deployment targets yet.

1. Identify the source file and its intended home-directory target.
2. Remove secret values; use only explicitly reviewed config files.
3. Declare a **single** mise-managed target rather than linking a whole
   application directory or adding a bespoke symlink script.
4. Preview the proposed diff and inspect existing files or symlinks.
5. Require a precise yes/no prompt for every modifying action.
6. Test refusal, already-correct state, conflicts and reruns in an isolated HOME.
7. Only after verification, migrate one real configuration and update the guide.

Existing `.config/nvim`, `.config/zellij` and `.config/ghostty` are currently
empty placeholders. Read [the design](../architecture/index.md) for context.
