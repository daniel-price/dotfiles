#!/usr/bin/env python3
"""Regression checks for safe opt-in native mise module wiring (no network)."""
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
bootstrap = tomllib.loads((ROOT / "src/mise.toml").read_text())
global_config = tomllib.loads((ROOT / "src/home/.config/mise/config.toml").read_text())
base_tools = tomllib.loads((ROOT / "src/home/.config/mise/base-tools.toml").read_text())
opencode = tomllib.loads((ROOT / "src/modules/opencode/config.opencode.toml").read_text())

assert bootstrap["include"] == ["./home/.config/mise/base-tools.toml"]
assert global_config["include"] == ["./base-tools.toml"]
assert "tools" not in bootstrap and "tools" not in global_config
assert "opencode" not in base_tools["tools"], "OpenCode must be opt-in"
# Selecting OpenCode only exposes a launcher, never a native host agent.
assert "tools" not in opencode and "bootstrap" not in opencode
assert opencode == {"env": {"_": {"path": ["~/.dotfiles/src/modules/opencode/bin"]}}}
assert "opencode" not in base_tools["tools"]
assert "opencode" not in tomllib.loads((ROOT / "dev/mise.toml").read_text()).get("tools", {})
assert not (ROOT / "src/bin/opencode-sandbox").exists(), "Base bin/ must not expose OpenCode"
launcher = ROOT / "src/modules/opencode/bin/opencode-sandbox"
assert launcher.is_file() and launcher.stat().st_mode & 0o111, "Sandbox launcher must be executable"
assert (ROOT / "src/modules/opencode/Containerfile").is_file()
assert "src/modules/opencode/bin" not in (ROOT / "src/home/.zshrc").read_text()
assert "src/modules/opencode/bin" not in (ROOT / "src/home/.config/mise/config.toml").read_text()
assert bootstrap["settings"]["auto_install"] is False
assert global_config["settings"]["auto_install"] is False

symlinks = {
    "config.toml": "home/.config/mise/config.toml",
    "base-tools.toml": "home/.config/mise/base-tools.toml",
    "config.opencode.toml": "modules/opencode/config.opencode.toml",
}
for target, source in symlinks.items():
    assert bootstrap["dotfiles"][f"~/.config/mise/{target}"] == {
        "source": source, "mode": "symlink"
    }
    assert (ROOT / "src" / source).resolve().is_file()
for manifest in (bootstrap, global_config, base_tools, opencode):
    assert "bootstrap" not in manifest or "repos" not in manifest["bootstrap"], (
        "Public config must not clone private repositories"
    )

# A developer checkout must not offer Base machine tools from a discovered
# src/home/.config/mise/config.toml; only dev/mise.toml declares developer tools.
assert not (ROOT / ".config/mise/config.toml").exists()

startup = (ROOT / "src/home/.zshrc").read_text()
assert "profiles.zsh" not in startup
assert "MISE_GLOBAL_CONFIG_FILE" not in startup
assert "mise activate zsh" in startup
assert not (ROOT / "src/home/.config/zsh/profiles.zsh").exists()
assert not (ROOT / "src/lib/setup/profile.sh").exists()
assert not (ROOT / "src/lib/setup/profile-config.py").exists()
assert not (ROOT / "src/bin/,profile").exists()

print("PASS: Shared Base and optional sandbox-only OpenCode, never host-installed")
