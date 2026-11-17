#!/usr/bin/env python3
"""PTY-backed tests for the opt-in zsh startup deployment."""
import os
import pty
import shutil
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "scripts" / "setup" / "deploy-zsh-config.sh"
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
assert "zoxide init zsh" in SOURCE.read_text(), SOURCE.read_text()

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
    args = []

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
        SCRIPT, [], make_env(real_home, real_log)
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
        SCRIPT, [], make_env(link_home, link_log)
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
        SCRIPT, [], old_env
    )
    assert old_version.returncode != 0, old_version.stdout
    assert "2026.11.9 or newer" in old_version.stdout, old_version.stdout
    assert old_log.read_text() == ""


    # Check the real Zsh startup semantics with synthetic mise and zoxide.
    # The machine manifest must be resolved through the ~/.zshrc symlink,
    # otherwise a tool installed with mise -C / is invisible to new shells.
    if shutil.which("zsh"):
        tools_bin = temp_root / "tools"
        tools_bin.mkdir()
        zoxide_log = temp_root / "zoxide.log"
        zoxide_log.touch()
        (tools_bin / "zoxide").write_text("""#!/usr/bin/env bash
printf '%s\\n' "$*" >> "$MOCK_ZOXIDE_LOG"
[[ "$*" == 'init zsh' ]] || exit 60
printf '%s\\n' 'function z() { :; }'
""")
        (tools_bin / "zoxide").chmod(0o755)

        mise.write_text("""#!/usr/bin/env bash
printf '%s|%s\\n' "${MISE_GLOBAL_CONFIG_FILE:-unset}" "$*" >> "$MOCK_MISE_LOG"
[[ "$*" == 'activate zsh' ]] || exit 61
printf 'export PATH="%s:$PATH"\\n' "$MOCK_TOOLS_BIN"
""")
        mise.chmod(0o755)
        startup_env = make_env(home, log)
        startup_env.pop("MISE_GLOBAL_CONFIG_FILE", None)
        startup_env.update({
            "MOCK_TOOLS_BIN": str(tools_bin),
            "MOCK_ZOXIDE_LOG": str(zoxide_log),
        })
        check = 'source "$HOME/.zshrc"; (( $+functions[z] )) || exit 70; print -r -- "$MISE_GLOBAL_CONFIG_FILE"'
        started = subprocess.run(
            ["zsh", "-f", "-c", check], env=startup_env, cwd=temp_root,
            stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT, text=True, check=False, timeout=12,
        )
        machine_config = ROOT / "scripts" / "setup" / "mise.toml"
        assert started.returncode == 0, started.stdout
        assert str(machine_config) in started.stdout, started.stdout
        assert "init zsh" in zoxide_log.read_text(), zoxide_log.read_text()
        assert f"{machine_config}|activate zsh" in log.read_text(), log.read_text()

        # Respect deliberate user overrides; do not silently replace them.
        startup_env["MISE_GLOBAL_CONFIG_FILE"] = "/chosen/mise-config.toml"
        overridden = subprocess.run(
            ["zsh", "-f", "-c", check], env=startup_env, cwd=temp_root,
            stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT, text=True, check=False, timeout=12,
        )
        assert overridden.returncode == 0, overridden.stdout
        assert "/chosen/mise-config.toml" in overridden.stdout, overridden.stdout
        assert "/chosen/mise-config.toml|activate zsh" in log.read_text()
    else:
        print("SKIP: Zsh startup integration (zsh unavailable)")

    print("PASS: Zsh deployment consent, preview, conflicts, version, Zsh init and repeatability")
