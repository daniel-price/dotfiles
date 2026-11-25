#!/usr/bin/env python3
"""The standalone reset recognises stale links without requiring mise or a checkout."""
from pathlib import Path
import os
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "src/bin/,cleanup"

with tempfile.TemporaryDirectory(prefix="dotfiles-reset-") as scratch:
    home = Path(scratch).resolve()
    config = home / ".config"
    (config / "git").mkdir(parents=True)
    (config / "zellij").mkdir()
    old = home / ".dotfiles"
    (home / ".zshrc").symlink_to(old / "scripts/setup/../../.config/zsh/zshrc")
    (config / "git/config").write_text("unrelated")
    (config / "zellij/config.kdl").symlink_to(home / "foreign")
    env = {**os.environ, "HOME": str(home), "XDG_CONFIG_HOME": str(config),
           "XDG_DATA_HOME": str(home / ".local/share"), "XDG_CACHE_HOME": str(home / ".cache"),
           "XDG_STATE_HOME": str(home / ".local/state"), "PATH": "/usr/bin:/bin"}
    preview = subprocess.run(["bash", str(SCRIPT)], env=env, text=True,
                             capture_output=True, check=True)
    assert "Remove managed link" in preview.stdout, preview
    assert "Existing non-symlink" in preview.stderr, preview
    assert "Unrelated symlink" in preview.stderr, preview
    assert (home / ".zshrc").is_symlink()
    assert (config / "git/config").read_text() == "unrelated"
    refused = subprocess.run(["bash", str(SCRIPT), "--apply"], env=env,
                             stdin=subprocess.DEVNULL, capture_output=True)
    assert refused.returncode != 0
    assert (home / ".zshrc").is_symlink()

print("PASS: standalone reset previews stale links and refuses noninteractive apply")
