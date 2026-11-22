#!/usr/bin/env python3
"""Integration tests for the *actual* profile clone/activation command.

All remotes are temporary local Git repositories. Mise is mocked; nothing is installed.
"""
import json
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


def create_remote(base, label, tool, version, settings="settings.toml", variables=None):
    source = base / f"{label}-source"
    source.mkdir()
    git(source, "init", "-q")
    (source / "bin").mkdir()
    (source / "zsh/functions").mkdir(parents=True)
    (source / "config/profile-example").mkdir(parents=True)
    config = f'[tools]\n{tool} = "{version}"\n'
    if variables:
        config += "\n[env]\n" + "".join(
            f"{name} = {json.dumps(value)}\n" for name, value in variables.items()
        )
    (source / "mise.toml").write_text(config)
    cmd = source / "bin" / f",{label}-hello"
    cmd.write_text("#!/usr/bin/env bash\nprintf 'profile works\\n'\n")
    cmd.chmod(0o755)
    (source / "zsh/aliases.zsh").write_text(f"alias {label}-ping='printf ping'\n")
    (source / "zsh/functions" / f"{label}-greet").write_text("print -r -- hello\n")
    (source / "config/profile-example" / settings).write_text("test=true\n")
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

    personal = create_remote(
        tmp, "personal", "opencode", "2.3.0",
        variables={"EDITOR": "nvim", "DOTFILES_PROFILE_EXAMPLE": "personal-profile-active"},
    )
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
    assert data["env"]["EDITOR"] == "nvim"
    assert data["env"]["DOTFILES_PROFILE_EXAMPLE"] == "personal-profile-active"
    assert (home / ".config/profile-example/settings.toml").is_symlink()
    assert (home / ".config/profile-example/settings.toml").resolve() == (
        checkout / "config/profile-example/settings.toml"
    ).resolve()
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
    assert "install opencode@2.3.0" in log.read_text(), (stdout(reapply), log.read_text())

    # Independent second repo, distinct config target, activates both profiles.
    server = create_remote(
        tmp, "server", "fd", "10.5.2", settings="server.toml",
        variables={"SERVER_PROFILE_FLAG": "enabled"},
    )
    serverargs = ["--name", "server", "--repo", str(server)]
    second = run_cli([*serverargs, "--apply"], env, "y\ny\n")
    assert code(second) == 0, stdout(second)
    assert (home / ".dotfiles-profiles/server/.git").is_dir()
    assert registry.read_text().splitlines()[-2:] == ["personal", "server"]
    assert (home / ".config/profile-example/server.toml").is_symlink()
    assert len(list((home / ".dotfiles-profiles").iterdir())) == 2
    combined = tomllib.loads(manifest.read_text())
    assert combined["env"] == {
        "EDITOR": "nvim",
        "DOTFILES_PROFILE_EXAMPLE": "personal-profile-active",
        "SERVER_PROFILE_FLAG": "enabled",
    }

    # Conflict from a third repo: a different OpenCode pin must fail *before* writes.
    conflict = create_remote(tmp, "conflict", "opencode", "1.19.0", settings="conflict.toml")
    conflictargs = ["--name", "conflict", "--repo", str(conflict)]
    failed = run_cli([*conflictargs, "--apply"], env, "y\n")
    assert code(failed) != 0 and "Conflicting tool pin" in stdout(failed), stdout(failed)
    assert not (home / ".config/profile-example/conflict.toml").exists()
    assert "conflict" not in registry.read_text()

    # Two private repos cannot silently override the same environment variable.
    env_conflict = create_remote(
        tmp, "envconflict", "node", "22.14.0", settings="env-conflict.toml",
        variables={"EDITOR": "emacs"},
    )
    env_result = run_cli(
        ["--name", "envconflict", "--repo", str(env_conflict), "--apply"], env, "y\n"
    )
    assert code(env_result) != 0 and "Conflicting environment variable" in stdout(env_result)
    assert "envconflict" not in registry.read_text()
    assert not (home / ".config/profile-example/env-conflict.toml").exists()

    # Runtime-critical variables and templated expressions are refused.
    reserved_env = create_remote(
        tmp, "reserved", "node", "22.14.0", settings="reserved.toml",
        variables={"PATH": "/untrusted/bin"},
    )
    reserved_result = run_cli(
        ["--name", "reserved", "--repo", str(reserved_env), "--apply"], env, "y\n"
    )
    assert code(reserved_result) != 0 and "reserved or invalid environment" in stdout(reserved_result)
    template_env = create_remote(
        tmp, "templated", "node", "22.14.0", settings="templated.toml",
        variables={"CUSTOM_VALUE": '{{exec(command="whoami")}}'},
    )
    template_result = run_cli(
        ["--name", "templated", "--repo", str(template_env), "--apply"], env, "y\n"
    )
    assert code(template_result) != 0 and "literal, single-line" in stdout(template_result)

    # A pre-existing real application config must not be overwritten.
    (home / ".config/profile-example/foreign.toml").write_text("keep=true\n")
    foreign = create_remote(tmp, "foreign", "node", "22.14.0", settings="foreign.toml")
    foreignargs = ["--name", "foreign", "--repo", str(foreign)]
    refused = run_cli([*foreignargs, "--apply"], env, "y\n")
    assert code(refused) != 0 and "Existing non-profile file" in stdout(refused), stdout(refused)
    assert (home / ".config/profile-example/foreign.toml").read_text() == "keep=true\n"

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
            ["zsh", "-ic", "alias personal-ping; whence -w personal-greet; personal-greet; whence -w ,personal-hello; print -r -- $MISE_GLOBAL_CONFIG_FILE; print -r -- PROFILE_BIN=$PATH; print -r -- SCRATCH=${+parameters[profiles]}:${+parameters[registry]}:${+functions[_dotfiles_profiles_init]}"],
            env={**env, "MISE_GLOBAL_CONFIG_FILE": ""},
            cwd=tmp, capture_output=True, text=True, timeout=20,
        )
        assert out.returncode == 0, out.stdout + out.stderr
        assert "personal-ping" in out.stdout
        assert "personal-greet" in out.stdout
        assert "hello" in out.stdout
        assert ",personal-hello" in out.stdout
        assert str(manifest) in out.stdout
        assert str(checkout / "bin") in out.stdout
        assert "SCRATCH=0:0:0" in out.stdout, out.stdout

    # Deactivation previews changes, requests approval and never deletes Git repos.
    personal_deactivate = ["--name", "personal", "--deactivate"]
    preview_deactivate = run_cli(personal_deactivate, env)
    assert code(preview_deactivate) == 0, stdout(preview_deactivate)
    assert "Remove owned config symlink" in stdout(preview_deactivate)
    assert "personal" in registry.read_text()
    refused_deactivate = run_cli([*personal_deactivate, "--apply"], env, "n\n")
    assert code(refused_deactivate) == 0, stdout(refused_deactivate)
    assert "personal" in registry.read_text()

    # A replaced symlink belongs to someone else: do not remove it.
    personal_link = home / ".config/profile-example/settings.toml"
    personal_link.unlink()
    personal_link.symlink_to(home / ".config/profile-example/server.toml")
    foreign_link = run_cli([*personal_deactivate, "--apply"], env, "y\n")
    assert code(foreign_link) != 0
    assert "Foreign symlink" in stdout(foreign_link) or "altered symlink" in stdout(foreign_link)
    assert personal_link.is_symlink()
    assert "personal" in registry.read_text()
    personal_link.unlink()
    personal_link.symlink_to(checkout / "config/profile-example/settings.toml")

    applied_deactivate = run_cli([*personal_deactivate, "--apply"], env, "y\n")
    assert code(applied_deactivate) == 0, stdout(applied_deactivate)
    assert not personal_link.exists() and not personal_link.is_symlink()
    assert (home / ".config/profile-example/server.toml").is_symlink()
    assert (checkout / ".git").is_dir(), "Deactivation must retain cloned repo"
    assert registry.read_text().splitlines()[-1] == "server"
    after_deactivate = tomllib.loads(manifest.read_text())
    assert "opencode" not in after_deactivate["tools"]
    assert after_deactivate["env"] == {"SERVER_PROFILE_FLAG": "enabled"}
    assert "install opencode" in log.read_text(), "Deactivation should not uninstall existing tools"

    # Repeated deactivation is a clean no-op, never removing other profiles.
    no_op = run_cli([*personal_deactivate, "--apply"], env, "y\n")
    assert code(no_op) == 0 and "not active" in stdout(no_op)
    assert "server" in registry.read_text()

    # Last profile: restore public mise fallback by removing only managed files.
    last = run_cli(["--name", "server", "--deactivate", "--apply"], env, "y\n")
    assert code(last) == 0, stdout(last)
    assert not manifest.exists() and not registry.exists()
    assert not (home / ".config/profile-example/server.toml").exists()
    assert (home / ".dotfiles-profiles/server/.git").is_dir()
    assert sentinel.read_text() == "untouched"

    # A nested Zsh with a stale managed override must now fall back to Base.
    if shutil.which("zsh"):
        fallback = subprocess.run(
            ["zsh", "-ic", "print -r -- BASE=$MISE_GLOBAL_CONFIG_FILE"],
            env={**env, "MISE_GLOBAL_CONFIG_FILE": str(manifest)},
            cwd=tmp, capture_output=True, text=True, timeout=20,
        )
        assert fallback.returncode == 0, fallback.stdout + fallback.stderr
        assert "BASE=" + str(ROOT / "scripts/setup/mise.toml") in fallback.stdout

    print("PASS: real profile clone, env, consent, deactivation, Zsh, app links and conflicts")
