#!/usr/bin/env python3
"""Exercise update approval using real local Git history (never a public remote)."""
import os
import pty
import shutil
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GIT = shutil.which("git")
assert GIT, "Git is required for the local updater tests"

with tempfile.TemporaryDirectory(prefix="dotfiles-update-") as scratch:
    base = Path(scratch)
    home = base / "home"
    home.mkdir()
    bare, seed, checkout = (base / name for name in ("origin.git", "seed", "checkout"))
    bin_dir = base / "bin"
    bin_dir.mkdir()
    env = dict(os.environ)
    env.update({
        "HOME": str(home), "GIT_CONFIG_GLOBAL": os.devnull,
        "GIT_CONFIG_SYSTEM": os.devnull,
        "GIT_AUTHOR_NAME": "Local Test", "GIT_COMMITTER_NAME": "Local Test",
        "GIT_AUTHOR_EMAIL": "local@example.invalid",
        "GIT_COMMITTER_EMAIL": "local@example.invalid",
        "GIT_TERMINAL_PROMPT": "0",
        "MOCK_BOOTSTRAP_MARKER": str(base / "bootstrap.log"),
    })

    def git(*args):
        proc = subprocess.run([GIT, *map(str, args)], env=env,
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                              text=True, timeout=12)
        assert proc.returncode == 0, (args, proc.stdout, proc.stderr)
        return proc.stdout.strip()

    git("init", "--bare", "-q", bare)
    git("--git-dir", bare, "symbolic-ref", "HEAD", "refs/heads/main")
    git("init", "-q", seed)
    git("-C", seed, "checkout", "-q", "-b", "main")
    (seed / "setup").mkdir(parents=True)
    (seed / "lib").mkdir()
    (seed / "bin").mkdir()
    shutil.copy2(ROOT / "setup/update.sh", seed / "setup/update.sh")
    shutil.copy2(ROOT / "lib/common.sh", seed / "lib/common.sh")
    git("-C", seed, "remote", "add", "origin", bare)

    def push(version):
        # The updater itself changes on each push: it must continue running
        # safely while fast-forwarding a checkout that replaces its own file.
        (seed / "setup/update.sh").write_text(
            (ROOT / "setup/update.sh").read_text() +
            f"\n# synthetic updater revision {version}\n"
        )
        (seed / "bin/,bootstrap").write_text(
            "#!/usr/bin/env bash\n"
            f"printf '%s\\n' '{version}' >> \"$MOCK_BOOTSTRAP_MARKER\"\n"
        )
        git("-C", seed, "add", ".")
        git("-C", seed, "commit", "-qm", f"bootstrap {version}")
        git("-C", seed, "push", "-q", "origin", "main")

    push("v1")
    git("clone", "-q", bare, checkout)

    # The origin identity is stubbed, while all other Git commands run for
    # real against the isolated local bare repository.
    shim = bin_dir / "git"
    shim.write_text("""#!/usr/bin/env bash
if [[ "$1" == -C && "$3" == remote && "$4" == get-url && "$5" == origin ]]; then
  if [[ "$MOCK_BAD_ORIGIN" == 1 ]]; then
    echo 'https://example.invalid/other.git'
  else
    echo 'https://github.com/daniel-price/dotfiles.git'
  fi
  exit 0
fi
if [[ "$1" == -C && "$3" == fetch && "$MOCK_OFFLINE" == 1 ]]; then
  echo 'Offline fixture' >&2
  exit 1
fi
exec "@GIT@" "$@"
""".replace("@GIT@", GIT))
    shim.chmod(0o755)
    env.update({"PATH": str(bin_dir) + os.pathsep + env["PATH"],
                "MOCK_BAD_ORIGIN": "0", "MOCK_OFFLINE": "0"})

    def run(command, answers=None, overrides=None):
        run_env = {**env, **(overrides or {})}
        if answers is None:
            p = subprocess.run(["bash", *map(str, command)], env=run_env, cwd=base,
                               stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT, text=True, timeout=12)
            return p.returncode, p.stdout
        master, slave = pty.openpty()
        try:
            p = subprocess.Popen(["bash", *map(str, command)], env=run_env,
                                 cwd=base, stdin=slave, stdout=subprocess.PIPE,
                                 stderr=subprocess.STDOUT)
            os.close(slave)
            slave = -1
            # Send keypresses without Enter; confirmation consumes one key.
            os.write(master, answers.replace("\n", "").encode())
            out = p.communicate(timeout=12)[0].decode(errors="replace")
            return p.returncode, out
        finally:
            os.close(master)
            if slave != -1:
                os.close(slave)

    script = checkout / "setup/update.sh"
    old = git("-C", checkout, "rev-parse", "HEAD")
    push("v2")
    new = git("-C", seed, "rev-parse", "HEAD")

    status, out = run([script])
    assert status == 0 and "Read-only status complete" in out, out
    assert git("-C", checkout, "rev-parse", "refs/remotes/origin/main") == old
    status, out = run([script, "--apply"])
    assert status == 0 and "Fetch declined" in out, out
    status, out = run([script, "--apply", "--require-current"])
    assert status != 0 and "bootstrap will not run" in out, out
    status, out = run([script, "--apply"], "n\n")
    assert status == 0 and "Fetch declined" in out, out
    assert git("-C", checkout, "rev-parse", "refs/remotes/origin/main") == old

    status, out = run([script, "--apply"], "y\nn\n")
    assert status == 0 and "Fast-forward declined" in out, out
    assert git("-C", checkout, "rev-parse", "HEAD") == old
    assert git("-C", checkout, "rev-parse", "refs/remotes/origin/main") == new
    status, out = run([script, "--apply"], "y\ny\n")
    assert status == 0 and "Fast-forwarded main by 1" in out, out
    assert git("-C", checkout, "rev-parse", "HEAD") == new
    status, out = run([script, "--apply"], "y\n")
    assert status == 0 and "already current" in out, out

    # The independent updater can switch from a feature branch and fast-forward
    # main. It must not run provisioning; the caller runs bootstrap separately.
    git("-C", checkout, "switch", "-qc", "feature/test")
    feature_head = git("-C", checkout, "rev-parse", "HEAD")
    push("v3")
    status, out = run([script, "--apply"], "y\ny\n")
    assert status == 0 and "Checkout update complete" in out, out
    assert git("-C", checkout, "branch", "--show-current") == "main"
    assert git("-C", checkout, "rev-parse", "HEAD") == git("-C", seed, "rev-parse", "HEAD")
    assert git("-C", checkout, "rev-parse", "refs/heads/feature/test") == feature_head
    assert "v3" in (checkout / "bin/,bootstrap").read_text()
    assert not (base / "bootstrap.log").exists(), "updater must not run provisioning"

    # A dirty checkout (including untracked files) must not fetch or switch.
    git("-C", checkout, "switch", "-q", "feature/test")
    (checkout / "scratch").write_text("preserve\n")
    cached = git("-C", checkout, "rev-parse", "refs/remotes/origin/main")
    push("v4")
    status, out = run([script, "--apply"], "y\ny\n")
    assert status == 0 and "Update skipped" in out, out
    assert git("-C", checkout, "branch", "--show-current") == "feature/test"
    assert git("-C", checkout, "rev-parse", "refs/remotes/origin/main") == cached
    assert (checkout / "scratch").read_text() == "preserve\n"
    (checkout / "scratch").unlink()

    status, out = run([script, "--apply"], "y\nn\n")
    assert status == 0 and "Branch switch declined" in out, out
    assert git("-C", checkout, "branch", "--show-current") == "feature/test"
    current = git("-C", checkout, "rev-parse", "HEAD")
    status, out = run([script, "--apply"], "y\n", {"MOCK_OFFLINE": "1"})
    assert status == 0 and "Could not fetch origin/main" in out, out
    status, out = run([script, "--apply"], "y\n", {"MOCK_BAD_ORIGIN": "1"})
    assert status != 0 and "Unexpected origin URL" in out, out
    assert git("-C", checkout, "rev-parse", "HEAD") == current

    # Local main ahead/diverged from origin/main is never overwritten.
    git("-C", checkout, "switch", "-q", "main")
    (checkout / "local-only").write_text("local\n")
    git("-C", checkout, "add", ".")
    git("-C", checkout, "commit", "-qm", "local main change")
    local_head = git("-C", checkout, "rev-parse", "HEAD")
    status, out = run([script, "--apply"], "y\n")
    assert status == 0 and "No automatic switch, reset or merge" in out, out
    assert git("-C", checkout, "rev-parse", "HEAD") == local_head

    git("-C", checkout, "checkout", "--detach", "-q")
    status, out = run([script, "--apply"], "y\n")
    assert status == 0 and "Detached HEAD" in out, out
    assert git("-C", checkout, "rev-parse", "HEAD") == local_head

    print("PASS: Local Git update preview, consent, fast-forward, branch safety and no automatic provisioning")
