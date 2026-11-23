#!/usr/bin/env python3
"""Regression checks for safe opt-in native mise module wiring (no network)."""
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
bootstrap = tomllib.loads((ROOT / "scripts/setup/mise.toml").read_text())
global_config = tomllib.loads((ROOT / "scripts/setup/global-mise.toml").read_text())
base_tools = tomllib.loads((ROOT / "scripts/setup/base-tools.toml").read_text())
opencode = tomllib.loads((ROOT / "scripts/setup/config.opencode.toml").read_text())

assert bootstrap["include"] == ["./base-tools.toml"]
assert global_config["include"] == ["./base-tools.toml"]
assert "tools" not in bootstrap and "tools" not in global_config
assert "opencode" not in base_tools["tools"], "OpenCode must be opt-in"
# Selecting OpenCode only exposes a launcher, never a native host agent.
assert "tools" not in opencode and "bootstrap" not in opencode
assert opencode == {"env": {"_": {"path": ["~/.dotfiles/modules/opencode/bin"]}}}
assert "opencode" not in base_tools["tools"]
assert "opencode" not in tomllib.loads((ROOT / "mise.toml").read_text()).get("tools", {})
assert not (ROOT / "bin/opencode-sandbox").exists(), "Base bin/ must not expose OpenCode"
launcher = ROOT / "modules/opencode/bin/opencode-sandbox"
assert launcher.is_file() and launcher.stat().st_mode & 0o111, "Sandbox launcher must be executable"
assert (ROOT / "containers/opencode/Containerfile").is_file()
assert "modules/opencode/bin" not in (ROOT / ".config/zsh/zshrc").read_text()
assert "modules/opencode/bin" not in (ROOT / "scripts/setup/global-mise.toml").read_text()
assert bootstrap["settings"]["auto_install"] is False
assert global_config["settings"]["auto_install"] is False

symlinks = {
    "config.toml": "global-mise.toml",
    "base-tools.toml": "base-tools.toml",
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

# A developer checkout must not offer Base machine tools from a discovered
# .config/mise/config.toml; only the root mise.toml declares dev tools.
assert not (ROOT / ".config/mise/config.toml").exists()

startup = (ROOT / ".config/zsh/profiles.zsh").read_text()
assert 'elif [[ ! -f "$HOME/.config/mise/config.toml" ]]' in startup
assert "unset MISE_GLOBAL_CONFIG_FILE" in startup

print("PASS: Shared Base and optional sandbox-only OpenCode, never host-installed")
