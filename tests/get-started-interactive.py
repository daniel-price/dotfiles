#!/usr/bin/env python3
"""Optional PTY-backed tests: no real Git clones or package installs."""
import os
import pty
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "get-started.sh"

with tempfile.TemporaryDirectory(prefix="dotfiles-bootstrap-pty-") as scratch:
    temp = Path(scratch)
    bin_dir = temp / "bin"
    bin_dir.mkdir()
    home = temp / "home"
    home.mkdir()
    log = temp / "clones"
    marker = temp / "bootstrap-marker"
    fake_git = bin_dir / "git"
    fake_git.write_text("""#!/usr/bin/env bash
case "$1" in
  --version) echo 'git version fake';;
  -C)
    case "$3" in
      rev-parse) printf '%s\\n' "$2";;
      remote) echo 'https://github.com/daniel-price/dotfiles.git';;
      *) exit 4;;
    esac;;
  clone)
    printf '%s\\n' "$4" >> "$MOCK_CLONE_LOG"
    mkdir -p "$4/bin"
    cat > "$4/bin/,bootstrap" <<'BOOT'
#!/usr/bin/env bash
[[ "$1" == --no-update ]] || exit 17
printf '%s\\n' "$PWD" > "$MOCK_BOOTSTRAP_MARKER"
[[ "${MOCK_BOOTSTRAP_FAIL:-0}" != 1 ]]
BOOT
    ;;
  *) exit 5;;
esac
""")
    fake_git.chmod(0o755)

    def run_tty(answers, *, should_fail=False):
        env = dict(os.environ)
        env.update({
            "HOME": str(home),
            "PATH": str(bin_dir) + os.pathsep + env["PATH"],
            "MOCK_CLONE_LOG": str(log),
            "MOCK_BOOTSTRAP_MARKER": str(marker),
            "MOCK_BOOTSTRAP_FAIL": "1" if should_fail else "0",
        })
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

    # Declined clone never runs bootstrap.
    status, output = run_tty("n\n")
    assert status == 0, output
    assert not (home / ".dotfiles").exists()
    assert not marker.exists()

    # Clone approval does not imply permission to run cloned code.
    status, output = run_tty("y\nn\n")
    assert status == 0, output
    assert (home / ".dotfiles" / "bin" / ",bootstrap").exists()
    assert not marker.exists(), output
    assert log.read_text().count("\n") == 1
    assert "Bootstrap execution declined" in output, output

    # Explicit bootstrap approval; existing repo is reused without a second clone.
    status, output = run_tty("y\n")
    assert status == 0, output
    assert marker.read_text().strip() == str(home / ".dotfiles"), output
    assert log.read_text().count("\n") == 1, "Unexpected second clone"

    # Errors inside the checkout bootstrap must cause stage zero to fail.
    marker.unlink()
    status, output = run_tty("y\n", should_fail=True)
    assert status != 0 and "Checkout bootstrap failed" in output, output

    print("PASS: PTY canonical handoff, confirmation, idempotence and failure propagation")

    # The shell-only test suite must also finish when invoked from an actual
    # terminal without input. CI's default non-TTY stdin would miss this bug.
    master, slave = pty.openpty()
    try:
        process = subprocess.Popen(
            ["bash", str(ROOT / "tests" / "get-started.sh")],
            stdin=slave, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            cwd=temp, env=os.environ.copy(),
        )
        os.close(slave)
        slave = -1
        try:
            output = process.communicate(timeout=12)[0].decode(errors="replace")
        except subprocess.TimeoutExpired:
            process.kill()
            process.communicate()
            raise AssertionError(
                "Stage-zero shell tests blocked on inherited terminal input"
            ) from None
        assert process.returncode == 0, output
        assert "PASS: Stage-zero Git bootstrap" in output, output
    finally:
        os.close(master)
        if slave != -1:
            os.close(slave)
    print("PASS: Stage-zero shell tests do not read from an inherited terminal")
