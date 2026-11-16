#!/usr/bin/env python3
"""PTY-backed tests for bootstrap prerequisite consent and idempotency."""
import os
import platform
import pty
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "scripts" / "bootstrap.sh"


def supported_host():
    if platform.system() == "Darwin":
        return True
    if platform.system() != "Linux":
        return False
    for release in (Path("/etc/os-release"), Path("/usr/lib/os-release")):
        if not release.is_file():
            continue
        fields = {}
        for line in release.read_text().splitlines():
            if "=" in line:
                key, value = line.split("=", 1)
                fields[key] = value.strip('"\'')
        return fields.get("ID") in {"debian", "ubuntu", "pop"} or any(
            name in fields.get("ID_LIKE", "").split()
            for name in ("debian", "ubuntu")
        )
    return False


if not supported_host():
    print("SKIP: bootstrap prerequisite PTY tests (unsupported host)")
    raise SystemExit(0)


with tempfile.TemporaryDirectory(prefix="dotfiles-bootstrap-prerequisites-") as scratch:
    temp = Path(scratch)
    bin_dir = temp / "bin"
    state = temp / "state"
    bin_dir.mkdir()
    state.mkdir()
    log = temp / "installs"

    for tool in ("zsh", "curl"):
        executable = bin_dir / tool
        executable.write_text("""#!/usr/bin/env bash
tool=${0##*/}
[[ -e "$MOCK_STATE/$tool" ]] || exit 1
printf '%s fake\\n' "$tool"
""")
        executable.chmod(0o755)

    for installer in ("apt-get", "brew"):
        executable = bin_dir / installer
        executable.write_text("""#!/usr/bin/env bash
printf '%s:%s\\n' "${0##*/}" "$*" >> "$MOCK_INSTALL_LOG"
tool=${!#}
touch "$MOCK_STATE/$tool"
""")
        executable.chmod(0o755)

    sudo = bin_dir / "sudo"
    sudo.write_text("""#!/usr/bin/env bash
exec "$@"
""")
    sudo.chmod(0o755)

    env = dict(os.environ)
    env.update({
        "PATH": str(bin_dir) + os.pathsep + env["PATH"],
        "MOCK_INSTALL_LOG": str(log),
        "MOCK_STATE": str(state),
    })

    def run_tty(answers):
        master, slave = pty.openpty()
        try:
            process = subprocess.Popen(
                ["bash", str(SCRIPT)],
                stdin=slave, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                cwd=temp, env=env,
            )
            os.close(slave)
            slave = -1
            os.write(master, answers.encode())
            output = process.communicate(timeout=12)[0].decode(errors="replace")
            return process.returncode, output
        finally:
            os.close(master)
            if slave != -1:
                os.close(slave)

    # Refusing zsh does not block a separately approved curl installation.
    status, output = run_tty("n\ny\n")
    assert status == 0, output
    assert not (state / "zsh").exists(), output
    assert (state / "curl").exists(), output
    assert "Skipped zsh installation" in output, output

    log.unlink()
    (state / "curl").unlink()
    status, output = run_tty("y\ny\n")
    assert status == 0, output
    assert (state / "zsh").exists() and (state / "curl").exists(), output
    installs = log.read_text().splitlines()
    if platform.system() == "Linux":
        expected = ["apt-get:install --no-upgrade zsh", "apt-get:install --no-upgrade curl"]
    else:
        expected = ["brew:install zsh", "brew:install curl"]
    assert installs == expected, installs

    # A repeat run does not prompt or invoke the package manager.
    result = subprocess.run(
        ["bash", str(SCRIPT)],
        cwd=temp, env=env, stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, check=False,
    )
    assert result.returncode == 0, result.stdout
    assert "no installation needed" in result.stdout, result.stdout
    assert log.read_text().splitlines() == expected, log.read_text()

    print("PASS: Bootstrap prerequisite consent, package commands and repeatability")
