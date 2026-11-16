#!/usr/bin/env python3
"""PTY-backed tests for tool provisioning and the explicit private overlay."""
import os
import pty
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PROVISION = ROOT / "scripts" / "provision-tool.sh"
OVERLAY = ROOT / "scripts" / "apply-private-overlay.sh"


def run_tty(script, answers, env, args=None):
    master, slave = pty.openpty()
    try:
        process = subprocess.Popen(
            ["bash", str(script), *(args or [])],
            stdin=slave, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            cwd=temp, env=env,
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
        cwd=temp, env=env, stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, check=False,
    )


def git(args, cwd):
    subprocess.run(["git", *args], cwd=cwd, check=True,
                   stdout=subprocess.PIPE, stderr=subprocess.PIPE)


def commit(message, cwd):
    git(["-c", "user.name=Test", "-c", "user.email=test@example.invalid",
         "commit", "-m", message], cwd)


with tempfile.TemporaryDirectory(prefix="dotfiles-tool-overlay-") as scratch:
    temp = Path(scratch)
    bin_dir = temp / "bin"
    home = temp / "home"
    bin_dir.mkdir()
    home.mkdir()

    mise_fake = bin_dir / "mise"
    mise_fake.write_text("""#!/usr/bin/env bash
printf '%s\\n' "$*" >> "$MOCK_MISE_LOG"
case "$*" in
  --version) printf '%s\\n' '2026.11.9 fake' ;;
  *"install --dry-run-code"*)
    [[ -e "$MOCK_MISE_STATE" ]] && exit 0 || exit 1
    ;;
  *"install neovim@0.12.6"*)
    touch "$MOCK_MISE_STATE"
    exit 0
    ;;
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
    mise_fake.chmod(0o755)

    base_env = dict(os.environ)
    base_env.update({
        "HOME": str(home),
        "PATH": str(bin_dir) + os.pathsep + "/usr/bin:/bin",
        "MOCK_MISE_LOG": str(temp / "mise.log"),
        "MOCK_MISE_STATE": str(temp / "mise.state"),
        "MOCK_DOT_SOURCE": "",
        "MOCK_DOT_TARGET": "",
    })
    (temp / "mise.log").touch()

    def log_lines():
        return (temp / "mise.log").read_text().splitlines()

    unsupported = run_quiet(PROVISION, ["ghostty"], base_env)
    assert unsupported.returncode != 0, unsupported.stdout

    declined = run_tty(PROVISION, "n\n", base_env, ["neovim"])
    assert declined[0] == 0, declined[1]
    assert "Skipped neovim installation" in declined[1], declined[1]
    assert not (temp / "mise.state").exists(), declined[1]
    assert not any("install neovim@0.12.6" in line for line in log_lines()), log_lines()

    approved = run_tty(PROVISION, "y\n", base_env, ["neovim"])
    assert approved[0] == 0, approved[1]
    assert "Installed neovim@0.12.6" in approved[1], approved[1]
    assert (temp / "mise.state").exists(), approved[1]
    assert sum("install neovim@0.12.6" in line for line in log_lines()) == 1, log_lines()

    before_repeat = len(log_lines())
    repeated = run_quiet(PROVISION, ["neovim"], base_env)
    assert repeated.returncode == 0, repeated.stdout
    assert "already installed" in repeated.stdout, repeated.stdout
    assert len(log_lines()) == before_repeat + 1, log_lines()

    def make_source(name):
        source = temp / name
        git(["init", "-b", "main", str(source)], cwd=temp)
        (source / "init.lua").write_text("return {}\n")
        git(["add", "init.lua"], cwd=source)
        commit("initial", source)
        remote = temp / (name + "-remote.git")
        git(["init", "--bare", str(remote)], cwd=temp)
        git(["symbolic-ref", "HEAD", "refs/heads/main"], cwd=remote)
        git(["remote", "add", "origin", str(remote)], cwd=source)
        git(["push", "-u", "origin", "main"], cwd=source)
        return source, remote

    missing = run_quiet(
        OVERLAY,
        ["--source", str(temp / "missing"), "--target", str(home / ".config" / "nvim")],
        base_env,
    )
    assert missing.returncode != 0, missing.stdout

    source, remote = make_source("private-source")
    overlay_log = temp / "overlay.log"
    overlay_log.touch()
    overlay_env = dict(base_env)
    overlay_env["MOCK_MISE_LOG"] = str(overlay_log)
    target = home / ".config" / "nvim"
    target.parent.mkdir()

    def overlay_lines():
        return overlay_log.read_text().splitlines()

    real_dir = temp / "real-target"
    real_dir.mkdir()
    conflict = run_quiet(
        OVERLAY, ["--source", str(source), "--target", str(real_dir)], overlay_env
    )
    assert conflict.returncode != 0, conflict.stdout
    assert "real file or directory" in conflict.stdout, conflict.stdout
    assert overlay_lines() == [], overlay_lines()

    other = temp / "other"
    other.mkdir()
    wrong_link = home / ".config" / "wrong-link"
    wrong_link.symlink_to(other, target_is_directory=True)
    symlink_conflict = run_quiet(
        OVERLAY, ["--source", str(source), "--target", str(wrong_link)], overlay_env
    )
    assert symlink_conflict.returncode != 0, symlink_conflict.stdout
    assert "different symlink" in symlink_conflict.stdout, symlink_conflict.stdout
    assert overlay_lines() == [], overlay_lines()

    target.symlink_to(source, target_is_directory=True)
    already = run_quiet(
        OVERLAY, ["--source", str(source), "--target", str(target)], overlay_env
    )
    assert already.returncode == 0, already.stdout
    assert "already applied" in already.stdout, already.stdout
    assert overlay_lines() == [], overlay_lines()
    target.unlink()

    declined_overlay = run_tty(
        OVERLAY, "n\n",
        {**overlay_env, "MOCK_DOT_SOURCE": str(source), "MOCK_DOT_TARGET": str(target)},
        ["--source", str(source), "--target", str(target)],
    )
    assert declined_overlay[0] == 0, declined_overlay[1]
    assert "declined" in declined_overlay[1], declined_overlay[1]
    assert not target.exists(), declined_overlay[1]
    assert any("dot apply --dry-run" in line for line in overlay_lines()), overlay_lines()
    assert not any(line.endswith(" dot apply") for line in overlay_lines()), overlay_lines()

    applied = run_tty(
        OVERLAY, "y\n",
        {**overlay_env, "MOCK_DOT_SOURCE": str(source), "MOCK_DOT_TARGET": str(target)},
        ["--source", str(source), "--target", str(target)],
    )
    assert applied[0] == 0, applied[1]
    assert target.is_symlink(), applied[1]
    assert target.resolve() == source.resolve(), applied[1]
    assert sum(line.endswith(" dot apply") for line in overlay_lines()) == 1, overlay_lines()
    target.unlink()

    (source / "init.lua").write_text("return { changed = true }\n")
    dirty = run_quiet(
        OVERLAY, ["--source", str(source), "--target", str(target)], overlay_env
    )
    assert dirty.returncode != 0, dirty.stdout
    assert "uncommitted changes" in dirty.stdout, dirty.stdout
    git(["checkout", "--", "init.lua"], cwd=source)

    clone = temp / "remote-clone"
    git(["clone", str(remote), str(clone)], cwd=temp)
    git(["-c", "user.name=Test", "-c", "user.email=test@example.invalid",
         "commit", "--allow-empty", "-m", "remote change"], cwd=clone)
    git(["push", "origin", "HEAD:refs/heads/main"], cwd=clone)
    git(["-c", "user.name=Test", "-c", "user.email=test@example.invalid",
         "commit", "--allow-empty", "-m", "local change"], cwd=source)
    git(["fetch", "origin"], cwd=source)
    diverged = run_quiet(
        OVERLAY, ["--source", str(source), "--target", str(target)], overlay_env
    )
    assert diverged.returncode != 0, diverged.stdout
    assert "diverged" in diverged.stdout, diverged.stdout

    print("PASS: Neovim provisioning and private overlay consent, conflicts and repeatability")
