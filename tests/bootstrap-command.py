#!/usr/bin/env python3
"""Exercise ,bootstrap without accessing any real Git remote or user setup."""

import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
LAUNCHER = ROOT / "bin/,bootstrap"

with tempfile.TemporaryDirectory(prefix="dotfiles-bootstrap-command-") as scratch:
    base = Path(scratch)
    checkout = base / "checkout"
    (checkout / "bin").mkdir(parents=True)
    (checkout / "scripts/setup").mkdir(parents=True)
    (checkout / "scripts/lib").mkdir(parents=True)
    for library in ("common.sh", "os.sh", "mise.sh", "machine-tools.sh", "login-shell.sh"):
        (checkout / "scripts/lib" / library).write_text((ROOT / "scripts/lib" / library).read_text())
    (checkout / "bin/,bootstrap").write_text(LAUNCHER.read_text())
    (checkout / "scripts/setup/update.sh").write_text("""#!/usr/bin/env bash
printf '%s\\n' "$*" >> "$MOCK_UPDATE_LOG"
[[ "${MOCK_UPDATE_FAIL:-0}" == 0 ]] || exit 1
cat > "$MOCK_CHECKOUT/bin/,bootstrap" <<'BOOTSTRAP'
#!/usr/bin/env bash
[[ "$1" == --no-update ]] || exit 17
printf 'bootstrap ran\\n' >> "$MOCK_BOOTSTRAP_LOG"
BOOTSTRAP
""")
    (checkout / "scripts/setup/bootstrap.sh").write_text("""#!/usr/bin/env bash
printf 'bootstrap ran\\n' >> "$MOCK_BOOTSTRAP_LOG"
""")
    bin_dir = base / "mock-bin"
    bin_dir.mkdir()
    git = bin_dir / "git"
    git.write_text("""#!/usr/bin/env bash
case "$*" in
    *"symbolic-ref --quiet --short HEAD") printf '%s\\n' "${MOCK_BRANCH:-main}" ;;
    *"rev-parse HEAD") printf '%s\\n' "${MOCK_HEAD:-new}" ;;
    *"rev-parse refs/remotes/origin/main") printf '%s\\n' "${MOCK_REMOTE_HEAD:-new}" ;;
    *"status --porcelain --untracked-files=all") printf '%s' "${MOCK_DIRTY:-}" ;;
    *) exit 2 ;;
esac
""")
    git.chmod(0o755)
    update_log = base / "update.log"
    bootstrap_log = base / "bootstrap.log"
    env = dict(os.environ, PATH=str(bin_dir) + os.pathsep + os.environ["PATH"],
               MOCK_CHECKOUT=str(checkout),
               MOCK_UPDATE_LOG=str(update_log), MOCK_BOOTSTRAP_LOG=str(bootstrap_log))
    env.pop("DOTFILES_BOOTSTRAP_SNAPSHOT", None)
    env.pop("DOTFILES_BOOTSTRAP_ROOT", None)

    def run(*args, **overrides):
        update_log.unlink(missing_ok=True)
        bootstrap_log.unlink(missing_ok=True)
        (checkout / "bin/,bootstrap").write_text(LAUNCHER.read_text())
        return subprocess.run(["bash", str(checkout / "bin/,bootstrap"), *args],
                              env={**env, **overrides}, cwd=base,
                              stdin=subprocess.DEVNULL, capture_output=True,
                              text=True, timeout=10)

    helped = run("--help")
    assert helped.returncode == 0 and "Usage: ,bootstrap" in helped.stdout
    assert not update_log.exists() and not bootstrap_log.exists()

    succeeded = run()
    assert succeeded.returncode == 0, succeeded.stderr
    assert update_log.read_text().splitlines() == ["--apply --require-current"]
    assert bootstrap_log.read_text().splitlines() == ["bootstrap ran"]

    for overrides in (
        {"MOCK_UPDATE_FAIL": "1"},
        {"MOCK_BRANCH": "feature"},
        {"MOCK_HEAD": "old"},
        {"MOCK_DIRTY": "?? unexpected"},
    ):
        failed = run(**overrides)
        assert failed.returncode != 0, (overrides, failed.stdout, failed.stderr)
        assert not bootstrap_log.exists(), overrides

    unknown = run("--unknown")
    assert unknown.returncode != 0
    assert not update_log.exists() and not bootstrap_log.exists()

print("PASS: ,bootstrap update-first handoff and failed/unclean update refusal")
