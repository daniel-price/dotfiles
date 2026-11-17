#!/usr/bin/env python3
"""PTY-backed tests for pinned Zellij provisioning."""
import os
import pty
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "scripts" / "setup" / "provision-tool.sh"


def run_tty(answers, env):
    master, slave = pty.openpty()
    try:
        process = subprocess.Popen(
            ["bash", str(SCRIPT), "zellij"],
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
        ["bash", str(SCRIPT), "zellij"],
        cwd=temp_root, env=env, stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, check=False,
    )


with tempfile.TemporaryDirectory(prefix="dotfiles-zellij-") as scratch:
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
    touch "$MOCK_MISE_STATE_DIR/zellij_0.46.0"
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

    declined = run_tty("n\n", env)
    assert declined[0] == 0, declined[1]
    assert "Skipped zellij installation" in declined[1], declined[1]
    assert not (state_dir / "zellij_0.46.0").exists(), declined[1]
    assert not any("install zellij@0.46.0" in line for line in log_lines()), log_lines()

    approved = run_tty("y\n", env)
    assert approved[0] == 0, approved[1]
    assert "Installed zellij@0.46.0" in approved[1], approved[1]
    assert (state_dir / "zellij_0.46.0").exists(), approved[1]
    assert sum("install zellij@0.46.0" in line for line in log_lines()) == 1, log_lines()

    before_repeat = len(log_lines())
    repeated = run_quiet(env)
    assert repeated.returncode == 0, repeated.stdout
    assert "already installed" in repeated.stdout, repeated.stdout
    assert len(log_lines()) == before_repeat + 1, log_lines()

    print("PASS: Zellij provisioning consent, install and repeatability")
