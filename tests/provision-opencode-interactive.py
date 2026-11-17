#!/usr/bin/env python3
"""PTY-backed tests for pinned Node and OpenCode provisioning."""
import os
import pty
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "scripts" / "provision-tool.sh"


def run_tty(tool, answers, env):
    master, slave = pty.openpty()
    try:
        process = subprocess.Popen(
            ["bash", str(SCRIPT), tool],
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


def run_quiet(tool, env):
    return subprocess.run(
        ["bash", str(SCRIPT), tool],
        cwd=temp_root, env=env, stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, check=False,
    )


with tempfile.TemporaryDirectory(prefix="dotfiles-opencode-") as scratch:
    temp_root = Path(scratch)
    bin_dir = temp_root / "bin"
    home = temp_root / "home"
    state_dir = temp_root / "state"
    bin_dir.mkdir()
    home.mkdir()
    state_dir.mkdir()
    log = temp_root / "mise.log"
    log.touch()

    mise = bin_dir / "mise"
    mise.write_text("""#!/usr/bin/env bash
printf '%s\\n' "$*" >> "$MOCK_MISE_LOG"
case "$*" in
  --version) printf '%s\\n' '2026.11.9 fake' ;;
  *"install --dry-run-code"*)
    spec=${!#}
    key=${spec//@/_}
    [[ -e "$MOCK_MISE_STATE_DIR/$key" ]] && exit 0 || exit 1
    ;;
  *" install "*)
    spec=${!#}
    touch "$MOCK_MISE_STATE_DIR/${spec//@/_}"
    exit 0
    ;;
  *) exit 0 ;;
esac
""")
    mise.chmod(0o755)

    env = dict(os.environ)
    env.update({
        "HOME": str(home),
        "PATH": str(bin_dir) + os.pathsep + "/usr/bin:/bin",
        "MOCK_MISE_LOG": str(log),
        "MOCK_MISE_STATE_DIR": str(state_dir),
    })

    def log_lines():
        return log.read_text().splitlines()

    node_declined = run_tty("node", "n\n", env)
    assert node_declined[0] == 0, node_declined[1]
    assert "Skipped node installation" in node_declined[1], node_declined[1]
    assert not (state_dir / "node_24.11.0").exists(), node_declined[1]

    node_approved = run_tty("node", "y\n", env)
    assert node_approved[0] == 0, node_approved[1]
    assert "Installed node@24.11.0" in node_approved[1], node_approved[1]
    assert (state_dir / "node_24.11.0").exists(), node_approved[1]

    opencode_declined = run_tty("opencode", "n\n", env)
    assert opencode_declined[0] == 0, opencode_declined[1]
    assert "Skipped opencode installation" in opencode_declined[1], opencode_declined[1]
    assert not (state_dir / "opencode_2.3.0").exists(), opencode_declined[1]

    opencode_approved = run_tty("opencode", "y\n", env)
    assert opencode_approved[0] == 0, opencode_approved[1]
    assert "Installed opencode@2.3.0" in opencode_approved[1], opencode_approved[1]
    assert (state_dir / "opencode_2.3.0").exists(), opencode_approved[1]

    installs = log_lines()
    assert sum("install node@24.11.0" in line for line in installs) == 1, installs
    assert sum("install opencode@2.3.0" in line for line in installs) == 1, installs

    before_repeat = len(installs)
    node_repeat = run_quiet("node", env)
    assert node_repeat.returncode == 0, node_repeat.stdout
    assert "already installed" in node_repeat.stdout, node_repeat.stdout
    opencode_repeat = run_quiet("opencode", env)
    assert opencode_repeat.returncode == 0, opencode_repeat.stdout
    assert "already installed" in opencode_repeat.stdout, opencode_repeat.stdout
    assert len(log_lines()) == before_repeat + 2, log_lines()

    print("PASS: Node and OpenCode provisioning consent, install and repeatability")
