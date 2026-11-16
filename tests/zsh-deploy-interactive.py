#!/usr/bin/env python3
"""PTY-backed tests for the opt-in zsh startup deployment."""
import os
import pty
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "scripts" / "deploy-zsh-config.sh"
SOURCE = ROOT / ".config" / "zsh" / "zshrc"


def run_tty(script, answers, env, args):
    master, slave = pty.openpty()
    try:
        process = subprocess.Popen(
            ["bash", str(script), *args],
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


def run_quiet(script, args, env):
    return subprocess.run(
        ["bash", str(script), *args],
        cwd=temp_root, env=env, stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, check=False,
    )


assert SOURCE.is_file(), SOURCE
assert "mise activate zsh" in SOURCE.read_text(), SOURCE.read_text()

with tempfile.TemporaryDirectory(prefix="dotfiles-zsh-deploy-") as scratch:
    temp_root = Path(scratch)
    bin_dir = temp_root / "bin"
    home = temp_root / "home"
    bin_dir.mkdir()
    home.mkdir()
    log = temp_root / "mise.log"
    log.touch()

    mise = bin_dir / "mise"
    mise.write_text("""#!/usr/bin/env bash
printf '%s\\n' "$*" >> "$MOCK_MISE_LOG"
case "$*" in
  --version) printf '%s\\n' '2026.11.9 fake' ;;
  *"dot apply --dry-run"*) exit 0 ;;
  *"dot diff"*) exit 0 ;;
  *"dot apply"*)
    mkdir -p "$(dirname "$MOCK_DOT_TARGET")"
    ln -s "$MOCK_DOT_SOURCE" "$MOCK_DOT_TARGET"
    exit 0
    ;;
  *) exit 0 ;;
esac
""")
    mise.chmod(0o755)

    def make_env(home_dir, log_file):
        env = dict(os.environ)
        env.update({
            "HOME": str(home_dir),
            "PATH": str(bin_dir) + os.pathsep + "/usr/bin:/bin",
            "MOCK_MISE_LOG": str(log_file),
            "MOCK_DOT_SOURCE": str(SOURCE),
            "MOCK_DOT_TARGET": str(home_dir / ".zshrc"),
        })
        return env

    env = make_env(home, log)
    target = home / ".zshrc"
    args = ["--target", str(target)]

    declined = run_tty(SCRIPT, "n\n", env, args)
    assert declined[0] == 0, declined[1]
    assert "declined" in declined[1], declined[1]
    assert not target.exists(), declined[1]
    assert any("dot apply --dry-run" in line for line in log.read_text().splitlines())
    assert not any(line.endswith(" dot apply") for line in log.read_text().splitlines())

    approved = run_tty(SCRIPT, "y\n", env, args)
    assert approved[0] == 0, approved[1]
    assert target.is_symlink(), approved[1]
    assert target.resolve() == SOURCE.resolve(), approved[1]
    assert sum(line.endswith(" dot apply") for line in log.read_text().splitlines()) == 1

    before_repeat = len(log.read_text().splitlines())
    repeated = run_quiet(SCRIPT, args, env)
    assert repeated.returncode == 0, repeated.stdout
    assert "already applied" in repeated.stdout, repeated.stdout
    assert len(log.read_text().splitlines()) == before_repeat

    real_home = temp_root / "real-home"
    real_home.mkdir()
    (real_home / ".zshrc").write_text("existing\n")
    real_log = temp_root / "real.log"
    real_log.touch()
    conflict = run_quiet(
        SCRIPT, ["--target", str(real_home / ".zshrc")], make_env(real_home, real_log)
    )
    assert conflict.returncode != 0, conflict.stdout
    assert "real file or directory" in conflict.stdout, conflict.stdout
    assert real_log.read_text() == ""

    link_home = temp_root / "link-home"
    link_home.mkdir()
    other = temp_root / "other.zshrc"
    other.write_text("other\n")
    (link_home / ".zshrc").symlink_to(other)
    link_log = temp_root / "link.log"
    link_log.touch()
    link_conflict = run_quiet(
        SCRIPT, ["--target", str(link_home / ".zshrc")], make_env(link_home, link_log)
    )
    assert link_conflict.returncode != 0, link_conflict.stdout
    assert "different symlink" in link_conflict.stdout, link_conflict.stdout
    assert link_log.read_text() == ""

    old_bin = temp_root / "old-bin"
    old_bin.mkdir()
    old_mise = old_bin / "mise"
    old_mise.write_text("""#!/usr/bin/env bash
printf '%s\\n' '2026.8.15 linux-x64'
""")
    old_mise.chmod(0o755)
    old_home = temp_root / "old-home"
    old_home.mkdir()
    old_log = temp_root / "old.log"
    old_log.touch()
    old_env = make_env(old_home, old_log)
    old_env["PATH"] = str(old_bin) + os.pathsep + "/usr/bin:/bin"
    old_version = run_quiet(
        SCRIPT, ["--target", str(old_home / ".zshrc")], old_env
    )
    assert old_version.returncode != 0, old_version.stdout
    assert "2026.11.9 or newer" in old_version.stdout, old_version.stdout
    assert old_log.read_text() == ""

    print("PASS: Zsh deployment consent, preview, conflicts, version and repeatability")
