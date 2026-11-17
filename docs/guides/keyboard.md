# Caps Lock as Ctrl

Bootstrap offers to make **Caps Lock an additional Ctrl key** (the original Ctrl keys still work). It is an explicit, per-user choice, not a system-wide remap.

- **COSMIC:** updates only the `options` field in the existing `~/.config/cosmic/com.system76.CosmicComp/v1/xkb_config`. Open COSMIC Settings > Input Devices > Keyboard once if that file does not exist. Log out/in if the change does not take effect immediately.
- **GNOME:** adds `ctrl:nocaps` to the existing `org.gnome.desktop.input-sources xkb-options` GSettings array.
- **macOS:** uses built-in `hidutil` to remap Caps Lock to left Control immediately and installs `~/Library/LaunchAgents/com.daniel-price.dotfiles.caps-control.plist` to reapply it on login. It will not overwrite existing unrelated `hidutil` mappings or an occupied LaunchAgent path. Existing macOS Modifier Keys overrides should be checked manually in System Settings.

Other keyboard options are preserved. Bootstrap does not overwrite an existing conflicting Caps/Ctrl mapping, change keyboard layouts, or install a background remapping daemon. Other unsupported desktops are skipped.

To retry this step by itself, run `bash scripts/setup/keyboard.sh --apply` from the dotfiles checkout. On macOS, remove the LaunchAgent and run `hidutil property --set '{"UserKeyMapping":[]}'` to clear the mapping (only if no other mappings need preserving). For GNOME, undo by removing `ctrl:nocaps` from the existing XKB options. For COSMIC, remove `ctrl:nocaps` from the existing options in the keyboard configuration (or use COSMIC Settings).
