#!/usr/bin/env python3
"""Regression checks for safe opt-in native mise module wiring (no network)."""
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
bootstrap = tomllib.loads((ROOT / "scripts/setup/mise.toml").read_text())
global_config = tomllib.loads((ROOT / ".config/mise/config.toml").read_text())
base_tools = tomllib.loads((ROOT / ".config/mise/base-tools.toml").read_text())
opencode = tomllib.loads((ROOT / "scripts/setup/config.opencode.toml").read_text())

assert bootstrap["include"] == ["../../.config/mise/base-tools.toml"]
assert global_config["include"] == ["./base-tools.toml"]
assert "tools" not in bootstrap and "tools" not in global_config
assert "opencode" not in base_tools["tools"], "OpenCode must be opt-in"
assert opencode == {"tools": {"opencode": "2.3.0"}}
assert bootstrap["settings"]["auto_install"] is False
assert global_config["settings"]["auto_install"] is False

symlinks = {
    "config.toml": "../../.config/mise/config.toml",
    "base-tools.toml": "../../.config/mise/base-tools.toml",
    "config.opencode.toml": "config.opencode.toml",
}
for target, source in symlinks.items():
    assert bootstrap["dotfiles"][f"~/.config/mise/{target}"] == {
        "source": source, "mode": "symlink"
    }
    assert (ROOT / "scripts/setup" / source).resolve().is_file()
for manifest in (bootstrap, global_config, base_tools, opencode):
    assert "bootstrap" not in manifest or "repos" not in manifest["bootstrap"], (
        "Public config must not clone private repositories"
    )

startup = (ROOT / ".config/zsh/profiles.zsh").read_text()
assert 'elif [[ ! -f "$HOME/.config/mise/config.toml" ]]' in startup
assert "unset MISE_GLOBAL_CONFIG_FILE" in startup

print("PASS: One shared Base tool manifest and opt-in native mise modules")
