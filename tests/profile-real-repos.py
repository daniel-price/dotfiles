#!/usr/bin/env python3
"""Integration tests for the *actual* profile clone/activation command.

All remotes are temporary local Git repositories. Mise is mocked; nothing is installed.
"""
import os
from pathlib import Path
import pty
import shutil
import subprocess
import tempfile
import tomllib

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "scripts/setup/profile.sh"
HELPER = ROOT / "scripts/setup/profile-config.py"


def git(directory, *args):
    return subprocess.run(["git", "-C", str(directory), *args], check=True,
                          capture_output=True, text=True).stdout.strip()


def create_remote(base, label, tool, version, settings="settings.toml"):
    source = base / f"{label}-source"
    source.mkdir()
    git(source, "init", "-q")
    (source / "bin").mkdir()
    (source / "zsh/functions").mkdir(parents=True)
    (source / "config/profile-poc").mkdir(parents=True)
    (source / "mise.toml").write_text(f'[tools]\n{tool} = "{version}"\n')
    cmd = source / "bin" / f",{label}-hello"
    cmd.write_text("#!/usr/bin/env bash\nprintf 'profile works\\n'\n")
    cmd.chmod(0o755)
    (source / "zsh/aliases.zsh").write_text(f"alias {label}-ping='printf ping'\n")
    (source / "zsh/functions" / f"{label}-greet").write_text("print -r -- hello\n")
    (source / "config/profile-poc" / settings).write_text("test=true\n")
    git(source, "add", ".")
    git(source, "-c", "user.name=Profile Test", "-c",
        "user.email=test@example.invalid", "commit", "-qm", "Profile fixture")
    remote = base / f"{label}-remote.git"
    subprocess.run(["git", "clone", "--bare", str(source), str(remote)],
                   check=True, capture_output=True)
    return remote


def run_cli(args, env, answers=None):
    if answers is None:
        return subprocess.run(["bash", str(SCRIPT), *args], env=env, cwd=ROOT,
                              stdin=subprocess.DEVNULL, capture_output=True, text=True)
    master, slave = pty.openpty()
    try:
        process = subprocess.Popen(["bash", str(SCRIPT), *args], env=env, cwd=ROOT,
                                   stdin=slave, stdout=subprocess.PIPE,
                                   stderr=subprocess.STDOUT)
        os.close(slave)
        slave = -1
        os.write(master, answers.encode())
        output = process.communicate(timeout=45)[0].decode(errors="replace")
        return process.returncode, output
    finally:
        os.close(master)
        if slave != -1:
            os.close(slave)


def code(output):
    return output.returncode if hasattr(output, "returncode") else output[0]


def stdout(output):
    return output.stdout if hasattr(output, "stdout") else output[1]


with tempfile.TemporaryDirectory(prefix="dotfiles-real-profile-") as temp:
    tmp = Path(temp)
    home = tmp / "home"
    home.mkdir()
    sentinel = home / "sentinel"
    sentinel.write_text("untouched")
    localbin = tmp / "mock-bin"
    localbin.mkdir()
    log = tmp / "mise-log"
    log.write_text("")
    mise = localbin / "mise"
    mise.write_text("""#!/usr/bin/env bash
printf '%s\n' "$*" >> "$MOCK_MISE_LOG"
case "$*" in
  *"install --dry-run-code"*) exit 1 ;;
  *"install opencode@2.3.0"*) exit 0 ;;
esac
exit 0
""")
    mise.chmod(0o755)
    env = {
        **os.environ, "HOME": str(home),
        "PATH": str(localbin) + os.pathsep + os.environ["PATH"],
        "MOCK_MISE_LOG": str(log),
    }

    personal = create_remote(tmp, "personal", "opencode", "2.3.0")
    args = ["--name", "personal", "--repo", str(personal)]
    for bad in (["--name", "../unsafe", "--repo", str(personal)],
                ["--name", "personal", "--repo", "https://other.invalid/repo"]):
        result = run_cli(bad, env)
        assert code(result) != 0, stdout(result)

    preview = run_cli(args, env)
    assert code(preview) == 0, stdout(preview)
    assert not (home / ".dotfiles-profiles").exists(), "Preview created files"
    declined = run_cli([*args, "--apply"], env, "n\n")
    assert code(declined) == 0, stdout(declined)
    assert not (home / ".dotfiles-profiles").exists(), "Declined clone created files"

    declined_activation = run_cli([*args, "--apply"], env, "y\nn\n")
    assert code(declined_activation) == 0, stdout(declined_activation)
    checkout = home / ".dotfiles-profiles/personal"
    assert (checkout / ".git").is_dir()
    assert not (home / ".config/dotfiles").exists(), "Refused activation created registry"

    accepted = run_cli([*args, "--apply"], env, "y\nn\n")
    assert code(accepted) == 0, stdout(accepted)
    registry = home / ".config/dotfiles/active-profiles"
    manifest = home / ".config/mise/dotfiles-profiles.toml"
    assert registry.read_text().splitlines()[-1] == "personal"
    data = tomllib.loads(manifest.read_text())
    assert data["tools"]["opencode"] == "2.3.0"
    assert data["tools"]["ripgrep"] == "15.2.0"
    assert data["settings"]["auto_install"] is False
    assert (home / ".config/profile-poc/settings.toml").is_symlink()
    assert (home / ".config/profile-poc/settings.toml").resolve() == (
        checkout / "config/profile-poc/settings.toml"
    )
    assert (checkout / "bin/,personal-hello").is_file()
    assert (checkout / "zsh/aliases.zsh").is_file()
    assert (checkout / "zsh/functions/personal-greet").is_file()
    assert "install opencode@2.3.0" not in log.read_text(), "Declined tool was installed"
    assert sentinel.read_text() == "untouched"

    # Idempotent re-application: no auto-fetch, no duplication, no overwrite.
    before = git(checkout, "rev-parse", "HEAD")
    reapply = run_cli([*args, "--apply"], env, "y\ny\n")
    assert code(reapply) == 0, stdout(reapply)
    assert git(checkout, "rev-parse", "HEAD") == before
    assert registry.read_text().splitlines().count("personal") == 1
    assert "install opencode@2.3.0" in log.read_text(), "Approved tool not offered"

    # Independent second repo, distinct config target, activates both profiles.
    server = create_remote(tmp, "server", "fd", "10.5.2", settings="server.toml")
    serverargs = ["--name", "server", "--repo", str(server)]
    second = run_cli([*serverargs, "--apply"], env, "y\ny\n")
    assert code(second) == 0, stdout(second)
    assert (home / ".dotfiles-profiles/server/.git").is_dir()
    assert registry.read_text().splitlines()[-2:] == ["personal", "server"]
    assert (home / ".config/profile-poc/server.toml").is_symlink()
    assert len(list((home / ".dotfiles-profiles").iterdir())) == 2

    # Conflict from a third repo: a different OpenCode pin must fail *before* writes.
    conflict = create_remote(tmp, "conflict", "opencode", "1.19.0", settings="conflict.toml")
    conflictargs = ["--name", "conflict", "--repo", str(conflict)]
    failed = run_cli([*conflictargs, "--apply"], env, "y\n")
    assert code(failed) != 0 and "Conflicting tool pin" in stdout(failed), stdout(failed)
    assert not (home / ".config/profile-poc/conflict.toml").exists()
    assert "conflict" not in registry.read_text()

    # A pre-existing real application config must not be overwritten.
    (home / ".config/profile-poc/foreign.toml").write_text("keep=true\n")
    foreign = create_remote(tmp, "foreign", "node", "22.14.0", settings="foreign.toml")
    foreignargs = ["--name", "foreign", "--repo", str(foreign)]
    refused = run_cli([*foreignargs, "--apply"], env, "y\n")
    assert code(refused) != 0 and "Existing non-profile file" in stdout(refused), stdout(refused)
    assert (home / ".config/profile-poc/foreign.toml").read_text() == "keep=true\n"

    # A different remote cannot replace the approved profile checkout.
    mismatch = run_cli(["--name", "personal", "--repo", str(server), "--apply"], env, "y\n")
    assert code(mismatch) != 0 and "remote differs" in stdout(mismatch)
    assert sentinel.read_text() == "untouched"

    # Optional: prove real Zsh startup loads the approved aliases and bins,
    # without installing anything or sourcing unapproved repositories.
    if shutil.which("zsh"):
        zshrc = home / ".zshrc"
        zshrc.symlink_to(ROOT / ".config/zsh/zshrc")
        out = subprocess.run(
            ["zsh", "-ic", "alias personal-ping; whence -w personal-greet; whence -w ,personal-hello; print -r -- $MISE_GLOBAL_CONFIG_FILE"],
            env={**env, "MISE_GLOBAL_CONFIG_FILE": ""},
            cwd=tmp, capture_output=True, text=True, timeout=20,
        )
        assert out.returncode == 0, out.stdout + out.stderr
        assert "personal-ping" in out.stdout
        assert "personal-greet" in out.stdout
        assert ",personal-hello" in out.stdout
        assert str(manifest) in out.stdout

    print("PASS: real profile clone, consent, pinned tools, Zsh, app links, isolation and conflicts")
