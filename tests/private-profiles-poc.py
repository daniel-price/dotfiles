#!/usr/bin/env python3
"""Test isolated, independently committed profile Git fixtures using a PTY."""

import os
from pathlib import Path
import pty
import subprocess
import sys
import tempfile
import tomllib

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "scripts/poc/private-profiles.sh"
COMPOSER = ROOT / "scripts/poc/private-profile-tools.py"


# The script must require a terminal for any writing; tests emulate one with a PTY.
def run(args, env, response=None):
    if response is None:
        return subprocess.run(["bash", str(SCRIPT), *args], env=env, cwd=ROOT,
                              stdin=subprocess.DEVNULL, capture_output=True, text=True)
    master, slave = pty.openpty()
    try:
        process = subprocess.Popen(["bash", str(SCRIPT), *args], cwd=ROOT,
                                   env=env, stdin=slave, stdout=slave,
                                   stderr=slave, close_fds=True)
        os.close(slave)
        slave = -1
        os.write(master, response.encode())
        output = bytearray()
        while True:
            try:
                chunk = os.read(master, 4096)
            except OSError:
                break
            if not chunk:
                break
            output.extend(chunk)
        return process.wait(timeout=30), output.decode(errors="replace")
    finally:
        os.close(master)
        if slave != -1:
            os.close(slave)


with tempfile.TemporaryDirectory(prefix="dotfiles-profiles-test-") as tmp:
    tmp_path = Path(tmp)
    scratch = tmp_path / "workspaces"
    scratch.mkdir()
    real_home = tmp_path / "untouched-home"
    real_home.mkdir()
    sentinel = real_home / "do-not-touch"
    sentinel.write_text("original")
    env = {**os.environ, "TMPDIR": str(scratch), "HOME": str(real_home)}
    assert run([], env).returncode == 0
    assert not list(scratch.iterdir()), "Preview wrote files"
    assert run(["--help"], env).returncode == 0
    assert not list(scratch.iterdir())
    assert run(["--apply", "personal"], env).returncode != 0
    for invalid in ("invalid", "", "personal,", ",personal", "personal,,home-server",
                    "personal,personal", "personal,invalid"):
        assert run(["--apply", invalid], env).returncode != 0, invalid
    assert not list(scratch.iterdir()), "Invalid or noninteractive invocation wrote files"

    result, output = run(["--apply", "personal"], env, "n\n")
    assert result == 0 and "Declined" in output, output
    assert not list(scratch.iterdir()), "Refusal wrote files"

    variants = (
        ("personal", {"personal"}),
        ("home-server", {"home-server"}),
        ("work-mac", {"work-mac"}),
        ("personal,work-mac", {"personal", "work-mac"}),
    )
    tool_for = {"personal": "gh", "home-server": "fd", "work-mac": "node"}
    command_for = {"personal": ",personal-demo", "home-server": ",server-demo",
                   "work-mac": ",work-demo"}
    alias_for = {"personal": "poc_personal", "home-server": "poc_server",
                 "work-mac": "poc_work"}
    config_for = {"personal": "personal.conf", "home-server": "server.conf",
                  "work-mac": "work.conf"}
    for argument, selected in variants:
        result, output = run(["--apply", argument], env, "y\n")
        assert result == 0, output
        prefix = "Remove this disposable workspace after inspection: "
        workspace = Path(next(line.strip()[len(prefix):] for line in output.splitlines()
                              if line.strip().startswith(prefix)))
        repos = workspace / "profile-repos"
        home = workspace / "staged-home"
        assert workspace.parent == scratch
        assert not (repos / ".git").exists(), "Profiles must not share one repo"
        assert len([p for p in repos.iterdir() if p.is_dir()]) == 3
        for name in tool_for:
            repo = repos / f"{name}-profile"
            assert (repo / ".git").is_dir(), f"No independent Git repo for {name}"
            assert subprocess.run(["git", "-C", str(repo), "remote"],
                                  capture_output=True, text=True, check=True).stdout == ""
            commit = subprocess.run(["git", "-C", str(repo), "log", "-1", "--format=%s"],
                                    capture_output=True, text=True, check=True).stdout.strip()
            assert name in commit
            assert (repo / "mise.toml").is_file()
            assert (repo / "bin" / command_for[name]).is_file()
        config = tomllib.loads((home / ".config/mise/config.toml").read_text())
        assert config["settings"]["auto_install"] is False
        assert config["tools"]["ripgrep"] == "15.2.0"
        assert (home / ".local/bin/,shared-demo").is_file()
        assert (home / ".config/demo/shared.conf").is_file()
        aliases = (home / ".config/zsh/aliases.zsh").read_text()
        assert "poc_shared" in aliases
        for name in tool_for:
            assert (tool_for[name] in config["tools"]) == (name in selected), name
            assert (home / ".local/bin" / command_for[name]).exists() == (name in selected), name
            assert (alias_for[name] in aliases) == (name in selected), name
            assert (home / ".config/demo" / config_for[name]).exists() == (name in selected), name
        assert sentinel.read_text() == "original"
        assert list(real_home.iterdir()) == [sentinel], "Real HOME was changed"

    base = tmp_path / "base.toml"
    one = tmp_path / "one.toml"
    two = tmp_path / "two.toml"
    dest = tmp_path / "composed.toml"
    base.write_text('[tools]\nripgrep = "15.2.0"\n')
    one.write_text('[tools]\nfd = "10.5.2"\n')
    two.write_text('[tools]\nfd = "9.0.0"\n')
    bad = subprocess.run([sys.executable, str(COMPOSER), str(base), str(one),
                          str(two), str(dest)], capture_output=True, text=True)
    assert bad.returncode != 0 and "Conflicting tool pin" in bad.stderr
    assert not dest.exists(), "Conflicting profiles wrote a manifest"
    two.write_text('[tools]\nnode = "22.14.0"\n')
    subprocess.run([sys.executable, str(COMPOSER), str(base), str(one),
                    str(two), str(dest)], check=True)
    merged = tomllib.loads(dest.read_text())["tools"]
    assert set(merged) == {"ripgrep", "fd", "node"}
    again = subprocess.run([sys.executable, str(COMPOSER), str(base), str(one),
                            str(two), str(dest)], capture_output=True, text=True)
    assert again.returncode != 0 and "Refusing to overwrite" in again.stderr

print("PASS: separate Git repos, selected profile layering, consent, conflict refusal and HOME isolation")
