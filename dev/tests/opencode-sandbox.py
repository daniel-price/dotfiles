#!/usr/bin/env python3
"""Isolated rootless Podman launcher tests; synthetic Podman, never pull/build/run."""
import os
import pty
import shutil
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "modules" / "opencode" / "bin" / "opencode-sandbox"

with tempfile.TemporaryDirectory(prefix="dotfiles-agent-sandbox-") as scratch:
    base = Path(scratch)
    home, project, sibling, bin_dir, state = (
        base / name for name in ("home", "project space", "other-repository", "bin", "state")
    )
    for path in (home, project, sibling, bin_dir, state):
        path.mkdir()
    (home / ".ssh").mkdir()
    (home / ".ssh" / "id_ed25519").write_text("fake test credential")
    (sibling / "secret.env").write_text("fake test secret")
    subprocess.run(["git", "-C", str(project), "init", "-q"], check=True)
    log = base / "podman.log"
    log.touch()

    podman = bin_dir / "podman"
    podman.write_text('''#!/usr/bin/env bash
printf '%s\\n' "$*" >> "$MOCK_PODMAN_LOG"
case "$1" in
  --version) echo "podman (fake)" ;;
  info) printf '%s\\n' "${MOCK_ROOTLESS:-true}" ;;
  image)
    [[ "$2" == exists ]] || exit 30
    case "$3" in
      ghcr.io/*) [[ -e "$MOCK_STATE/base" ]] ;;
      localhost/*) [[ -e "$MOCK_STATE/local" ]] ;;
      *) exit 31 ;;
    esac
    ;;
  pull) touch "$MOCK_STATE/base" ;;
  build) touch "$MOCK_STATE/local" ;;
  run) printf '%s\\n' 'AGENT_MOCK_LAUNCHED' ;;
  *) exit 32 ;;
esac
''')
    podman.chmod(0o755)
    uname = bin_dir / "uname"
    uname.write_text('''#!/usr/bin/env bash
if [[ "$1" == -s ]]; then echo "${MOCK_KERNEL:-Linux}"; else /usr/bin/uname "$@"; fi
''')
    uname.chmod(0o755)
    fake_id = bin_dir / "id"
    fake_id.write_text('''#!/usr/bin/env bash
case "$1" in -u) echo 1000 ;; -g) echo 1000 ;; *) /usr/bin/id "$@" ;; esac
''')
    fake_id.chmod(0o755)

    env = dict(os.environ)
    env.update({"HOME": str(home), "PATH": str(bin_dir) + os.pathsep + os.environ["PATH"],
                "MOCK_PODMAN_LOG": str(log), "MOCK_STATE": str(state)})

    def run(args=(), *, answers=None, overrides=None):
        actual = {**env, **(overrides or {})}
        cmd = ["bash", str(SCRIPT), "--project", str(project), *args]
        if answers is None:
            return subprocess.run(cmd, env=actual, cwd=base, stdin=subprocess.DEVNULL,
                                  stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                  text=True, timeout=10, check=False)
        master, slave = pty.openpty()
        try:
            proc = subprocess.Popen(cmd, cwd=base, env=actual, stdin=slave,
                                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            os.close(slave)
            slave = -1
            os.write(master, answers.encode())
            stdout = proc.communicate(timeout=10)[0].decode(errors="replace")
            return subprocess.CompletedProcess(cmd, proc.returncode, stdout)
        finally:
            os.close(master)
            if slave != -1:
                os.close(slave)

    def operations():
        return log.read_text().splitlines()

    assert run(["--help"]).returncode == 0
    assert run(["--untrusted-flag"]).returncode != 0
    preview = run(["--dry-run"])
    assert preview.returncode == 0 and "Read-only preview" in preview.stdout, preview.stdout
    assert not operations(), operations()

    # Fail closed before touching Podman for invalid project scopes and shell vars.
    assert run(["--project", str(home)]).returncode != 0
    assert run(["--project", str(sibling)]).returncode != 0
    assert run(["--credential-env", "HOME"]).returncode != 0
    assert run(["--credential-env", "OPENAI_API_KEY"]).returncode != 0
    assert run([], overrides={"MOCK_KERNEL": "Darwin"}).returncode != 0
    assert not operations(), operations()

    # Refuse linked worktrees (whose .git metadata could be outside the mount).
    worktree = base / "linked-worktree"
    worktree.mkdir()
    (worktree / ".git").write_text("gitdir: /not/a/git/dir")
    assert run(["--project", str(worktree)]).returncode != 0
    assert not operations(), operations()

    rootful = run([], overrides={"MOCK_ROOTLESS": "false"})
    assert rootful.returncode != 0 and "not rootless" in rootful.stdout
    assert not any("pull " in line or "run " in line for line in operations())
    log.write_text("")

    # Piped yes and unattended execution must not approve any image changes.
    piped = subprocess.run(["bash", str(SCRIPT), "--project", str(project)],
                           input="yes\n" * 3, text=True, cwd=base, env=env,
                           stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=10)
    assert piped.returncode != 0 and not any("pull " in line for line in operations())
    log.write_text("")

    declined = run(answers="n\n")
    assert declined.returncode == 0 and "Declined image pull" in declined.stdout
    assert not (state / "base").exists() and not (state / "local").exists()
    assert not any(line.startswith(("pull ", "build ", "run ")) for line in operations())
    log.write_text("")

    approved = run(["--credential-env", "OPENAI_API_KEY"], answers="y\ny\ny\n",
                   overrides={"OPENAI_API_KEY": "synth-token-not-real"})
    assert approved.returncode == 0, approved.stdout
    assert "AGENT_MOCK_LAUNCHED" in approved.stdout
    assert (state / "base").exists() and (state / "local").exists()
    calls = operations()
    assert sum(line.startswith("pull ") for line in calls) == 1, calls
    assert sum(line.startswith("build ") for line in calls) == 1, calls
    launch = next(line for line in calls if line.startswith("run "))
    for required in ("--userns=keep-id", "--cap-drop=ALL", "--security-opt=no-new-privileges",
                     "--read-only", "--rm", "--pull=never", "--pids-limit=256",
                     "--memory=4g", "--workdir /workspace", "--env HOME=/tmp",
                     "--env OPENAI_API_KEY", f"--volume {project.resolve()}:/workspace:rw"):
        assert required in launch, (required, launch)
    for forbidden in (str(home), str(sibling), ".ssh", "docker.sock", "synth-token-not-real"):
        assert forbidden not in launch, (forbidden, launch)
    assert not any("synth-token-not-real" in line for line in calls), calls

    log.write_text("")
    repeated = run(answers="y\n")
    assert repeated.returncode == 0 and "AGENT_MOCK_LAUNCHED" in repeated.stdout
    assert not any(line.startswith(("pull ", "build ")) for line in operations())
    assert sum(line.startswith("run ") for line in operations()) == 1

    # Missing runtime is offered through the reusable mise-backed prerequisite,
    # not an inline apt command or a silent Podman installation.
    podman_template = bin_dir / "podman-template"
    podman.rename(podman_template)
    # Use a deliberately minimal PATH so a CI runner's real Podman cannot
    # hide the missing-runtime branch of the launcher.
    for name in ("bash", "git", "dirname", "cp", "chmod"):
        target = shutil.which(name)
        assert target is not None, name
        link = bin_dir / name
        if not link.exists():
            link.symlink_to(target)
    env["PATH"] = str(bin_dir)
    fake_mise = bin_dir / "mise"
    fake_mise.write_text('''#!/usr/bin/env bash
if [[ "$1" == --version ]]; then echo '2026.11.9 fake'; exit 0; fi
printf '%s|%s\n' "$MISE_GLOBAL_CONFIG_FILE" "$*" >> "$MOCK_MISE_LOG"
case "$*" in
  "-C / bootstrap --only packages --dry-run") exit 0 ;;
  "-C / bootstrap --only packages")
    cp "$MOCK_PODMAN_TEMPLATE" "$MOCK_BIN/podman"
    chmod +x "$MOCK_BIN/podman"
    ;;
  *) exit 83 ;;
esac
''')
    fake_mise.chmod(0o755)
    env.update({"MOCK_PODMAN_TEMPLATE": str(podman_template),
                "MOCK_BIN": str(bin_dir), "MOCK_MISE_LOG": str(log)})
    log.write_text("")
    refused_runtime = run(answers="n\n")
    assert refused_runtime.returncode != 0 and "was not installed" in refused_runtime.stdout
    assert not podman.exists()
    assert not any(line.startswith("run ") for line in operations())

    log.write_text("")
    approved_runtime = run(answers="y\ny\n")
    assert approved_runtime.returncode == 0, approved_runtime.stdout
    assert "AGENT_MOCK_LAUNCHED" in approved_runtime.stdout
    assert podman.exists()
    scoped = str(ROOT / "containers/podman/mise.toml")
    assert f"{scoped}|-C / bootstrap --only packages --dry-run" in operations()
    assert f"{scoped}|-C / bootstrap --only packages" in operations()
    assert any(line.startswith("run ") for line in operations())

    print("PASS: OpenCode rootless scope, dry-run, consent, explicit credentials and repeatability")
