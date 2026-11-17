#!/usr/bin/env python3
"""PTY-backed tests for OS-specific Ghostty installation."""
import os
import pty
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "scripts" / "install-ghostty.sh"


def run_tty(answers, env):
    master, slave = pty.openpty()
    try:
        process = subprocess.Popen(
            ["bash", str(SCRIPT)],
            stdin=slave, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            cwd=temp_root, env=env,
        )
        os.close(slave)
        slave = -1
        os.write(master, answers.encode())
        output = process.communicate(timeout=15)[0].decode(errors="replace")
        return process.returncode, output
    finally:
        os.close(master)
        if slave != -1:
            os.close(slave)


def run_quiet(env):
    return subprocess.run(
        ["bash", str(SCRIPT)],
        cwd=temp_root, env=env, stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, check=False,
    )


with tempfile.TemporaryDirectory(prefix="dotfiles-ghostty-") as scratch:
    temp_root = Path(scratch)
    bin_dir = temp_root / "bin"
    home = temp_root / "home"
    bin_dir.mkdir()
    home.mkdir()
    state = temp_root / "installed"
    candidate = temp_root / "candidate"
    log = temp_root / "commands.log"
    candidate.write_text("1.4.0\n")
    log.touch()

    scripts = {
        "dpkg-query": """#!/usr/bin/env bash
[[ -e "$MOCK_GHOSTTY_STATE" ]] && printf '%s\\n' 'install ok installed' || printf '%s\\n' 'deinstall ok config-files'
""",
        "apt-cache": """#!/usr/bin/env bash
printf '  Candidate: %s\\n' "$(cat "$MOCK_GHOSTTY_CANDIDATE")"
""",
        "apt-get": """#!/usr/bin/env bash
printf '%s\\n' "$*" >> "$MOCK_COMMAND_LOG"
[[ "$1" == install ]] && touch "$MOCK_GHOSTTY_STATE"
""",
        "add-apt-repository": """#!/usr/bin/env bash
printf '%s %s\\n' "${0##*/}" "$*" >> "$MOCK_COMMAND_LOG"
printf '%s\\n' '1.4.0' > "$MOCK_GHOSTTY_CANDIDATE"
""",
        "brew": """#!/usr/bin/env bash
printf '%s\\n' "$*" >> "$MOCK_COMMAND_LOG"
case "$1" in
  list) [[ -e "$MOCK_GHOSTTY_STATE" ]] || exit 1 ;;
  install) touch "$MOCK_GHOSTTY_STATE" ;;
esac
""",
        "sudo": """#!/usr/bin/env bash
exec "$@"
""",
        "uname": """#!/usr/bin/env bash
if [[ "${MOCK_DARWIN:-0}" == 1 ]]; then
  printf '%s\\n' Darwin
else
  /usr/bin/uname "$@"
fi
""",
    }
    for name, content in scripts.items():
        path = bin_dir / name
        path.write_text(content)
        path.chmod(0o755)

    env = dict(os.environ)
    env.update({
        "HOME": str(home),
        "PATH": str(bin_dir) + os.pathsep + "/usr/bin:/bin",
        "MOCK_GHOSTTY_STATE": str(state),
        "MOCK_GHOSTTY_CANDIDATE": str(candidate),
        "MOCK_COMMAND_LOG": str(log),
        "MOCK_DARWIN": "0",
    })

    def lines():
        return log.read_text().splitlines()

    state.touch()
    installed = run_quiet(env)
    assert installed.returncode == 0, installed.stdout
    assert "already installed" in installed.stdout, installed.stdout
    assert lines() == [], lines()
    state.unlink()

    declined = run_tty("n\n", env)
    assert declined[0] == 0, declined[1]
    assert "Skipped Ghostty installation" in declined[1], declined[1]
    assert not state.exists(), declined[1]
    assert not any(line.startswith("install ") for line in lines()), lines()

    approved = run_tty("y\n", env)
    assert approved[0] == 0, approved[1]
    assert "Installed Ghostty" in approved[1], approved[1]
    assert state.exists(), approved[1]
    assert "install ghostty" in lines(), lines()
    state.unlink()
    log.write_text("")

    candidate.write_text("(none)\n")
    ppa = run_tty("y\ny\n", env)
    assert ppa[0] == 0, ppa[1]
    assert state.exists(), ppa[1]
    assert any("add-apt-repository" in line for line in lines()), lines()
    assert "install ghostty" in lines(), lines()
    state.unlink()
    log.write_text("")
    candidate.write_text("1.4.0\n")

    mac_env = dict(env)
    mac_env["MOCK_DARWIN"] = "1"
    mac = run_tty("y\n", mac_env)
    assert mac[0] == 0, mac[1]
    assert state.exists(), mac[1]
    assert any(line.startswith("install --cask ghostty") for line in lines()), lines()

    print("PASS: Ghostty detection, apt, PPA and Homebrew consent")
