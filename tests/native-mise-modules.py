#!/usr/bin/env python3
"""Native mise module selection stays opt-in and private repos stay local."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import tomllib

ROOT = Path(__file__).resolve().parent.parent
base = tomllib.loads((ROOT / "scripts/setup/mise.toml").read_text())
opencode = tomllib.loads((ROOT / ".config/mise/config.opencode.toml").read_text())

assert "opencode" not in base["tools"]
assert opencode["tools"]["opencode"] == "2.3.0"
assert base["dotfiles"]["~/.config/mise/config.toml"]["source"].endswith("/mise.toml")
assert base["dotfiles"]["~/.config/mise/config.opencode.toml"]["source"].endswith(
    ".config/mise/config.opencode.toml"
)
assert base["settings"]["auto_install"] is False
assert "MISE_GLOBAL_CONFIG_FILE" not in (ROOT / ".config/mise/config.opencode.toml").read_text()

mise = shutil.which("mise")
if mise:
    with tempfile.TemporaryDirectory(prefix="dotfiles-native-mise-") as tmp:
        home = Path(tmp)
        config = home / ".config/mise"
        config.mkdir(parents=True)
        (config / "config.toml").symlink_to(ROOT / "scripts/setup/mise.toml")
        (config / "config.opencode.toml").symlink_to(
            ROOT / ".config/mise/config.opencode.toml"
        )
        env = dict(os.environ, HOME=str(home))
        for name in ("MISE_GLOBAL_CONFIG_FILE", "MISE_ENV",
                     "MISE_SYSTEM_CONFIG_FILE", "MISE_CONFIG_FILE"):
            env.pop(name, None)
        # Resolve the synthetic global config explicitly in CI.
        env["MISE_CONFIG_DIR"] = str(config)
        env.pop("XDG_CONFIG_HOME", None)

        def selected(names):
            (config / "miserc.local.toml").write_text(
                "env = [" + ", ".join(repr(n) for n in names) + "]\n"
            )
            result = subprocess.run(
                [mise, "-C", "/", "ls", "--current", "--no-header", "--no-truncate"],
                env=env, capture_output=True, text=True, timeout=20
            )
            assert result.returncode == 0, result.stderr
            return result.stdout

        work = selected(["work"])
        assert "opencode" not in work, work
        personal = selected(["personal", "opencode"])
        if "opencode" not in personal:
            config_result = subprocess.run(
                [mise, "-C", "/", "config", "ls"],
                env=env, capture_output=True, text=True, timeout=20
            )
            raise AssertionError(
                "OpenCode module not loaded.\n"
                f"mise ls: {personal!r}\n"
                f"mise config ls: {config_result.stdout!r}\n"
                f"mise config stderr: {config_result.stderr!r}"
            )
        assert "opencode" in selected(["home-server", "opencode", "radarr"])
        assert "opencode" not in selected(["home-server", "radarr"])

        # A private conf.d folder is loaded only for its selected environment.
        private_module = config / "conf.d/radarr"
        private_module.mkdir(parents=True)
        (private_module / "mise.radarr.toml").write_text(
            """[tools]
just = "1.40.0"
"""
        )
        assert "just" not in selected(["personal", "opencode"])
        assert "just" in selected(["home-server", "radarr"])
else:
    print("SKIP: real native mise resolution (mise not installed)")

print("PASS: Optional OpenCode module remains off on work and opt-in elsewhere")
