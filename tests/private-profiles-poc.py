#!/usr/bin/env python3
"""Exercise the local-only profile POC through a pseudo-terminal."""

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
    env = {**os.environ, "TMPDIR": tmp}
    assert run([], env).returncode == 0
    assert not list(Path(tmp).iterdir()), "Preview wrote files"
    assert run(["--apply", "laptop"], env).returncode != 0
    assert not list(Path(tmp).iterdir()), "Noninteractive run wrote files"
    assert run(["--apply", "invalid"], env).returncode != 0
    assert not list(Path(tmp).iterdir()), "Invalid profile wrote files"

    result, output = run(["--apply", "laptop"], env, "n\n")
    assert result == 0 and "Declined" in output, output
    assert not list(Path(tmp).iterdir()), "Refusal wrote files"

    for selected in ("laptop", "home-server"):
        result, output = run(["--apply", selected], env, "y\n")
        assert result == 0, output
        prefix = "Remove this disposable workspace after inspection: "
        workspace = Path(next(line.strip()[len(prefix):] for line in output.splitlines()
                              if line.strip().startswith(prefix)))
        git_repo = workspace / "private-fixture"
        home = workspace / "staged-home"
        assert (git_repo / ".git").is_dir()
        assert subprocess.run(["git", "-C", str(git_repo), "remote"],
                              capture_output=True, text=True, check=True).stdout == ""
        assert subprocess.run(["git", "-C", str(git_repo), "log", "-1", "--format=%s"],
                              capture_output=True, text=True, check=True).stdout.strip()
        assert (git_repo / "profiles/laptop/mise.toml").is_file()
        assert (git_repo / "profiles/home-server/mise.toml").is_file()
        tools = tomllib.loads((home / ".config/mise/config.toml").read_text())["tools"]
        assert tools["ripgrep"] == "15.2.0"
        expected_tool = "gh" if selected == "laptop" else "fd"
        other_tool = "fd" if selected == "laptop" else "gh"
        assert expected_tool in tools and other_tool not in tools, tools
        assert (home / ".local/bin/,shared-demo").is_file()
        expected_cmd = ",laptop-demo" if selected == "laptop" else ",server-demo"
        other_cmd = ",server-demo" if selected == "laptop" else ",laptop-demo"
        assert (home / ".local/bin" / expected_cmd).is_file()
        assert not (home / ".local/bin" / other_cmd).exists()
        aliases = (home / ".config/zsh/aliases.zsh").read_text()
        assert "poc_shared" in aliases
        assert ("poc_laptop" in aliases) == (selected == "laptop")
        assert ("poc_server" in aliases) == (selected == "home-server")
        expected_conf = "laptop.conf" if selected == "laptop" else "server.conf"
        other_conf = "server.conf" if selected == "laptop" else "laptop.conf"
        assert (home / ".config/demo/shared.conf").is_file()
        assert (home / ".config/demo" / expected_conf).is_file()
        assert not (home / ".config/demo" / other_conf).exists()

    base = Path(tmp) / "base.toml"
    profile = Path(tmp) / "profile.toml"
    dest = Path(tmp) / "composed.toml"
    base.write_text('[tools]\nripgrep = "15.2.0"\n')
    profile.write_text('[tools]\nripgrep = "14.0.0"\n')
    bad = subprocess.run([sys.executable, str(COMPOSER), str(base), str(profile), str(dest)],
                         capture_output=True, text=True)
    assert bad.returncode != 0 and "Conflicting tool pin" in bad.stderr
    assert not dest.exists()
    profile.write_text('[tools]\nfd = "10.5.2"\n')
    subprocess.run([sys.executable, str(COMPOSER), str(base), str(profile), str(dest)], check=True)
    assert dest.exists()
    again = subprocess.run([sys.executable, str(COMPOSER), str(base), str(profile), str(dest)],
                           capture_output=True, text=True)
    assert again.returncode != 0 and "Refusing to overwrite" in again.stderr

print("PASS: Private profile fixture isolation, refusal, tool conflicts and non-overwrite")
