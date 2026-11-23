#!/usr/bin/env python3
"""Developer setup must work without mise on PATH and never install hooks without consent."""
import os
import pty
import shutil
import subprocess
import tempfile
from pathlib import Path

from confirmations import Confirm, Deny, communicate_confirmations

ROOT = Path(__file__).resolve().parents[2]

with tempfile.TemporaryDirectory(prefix="dotfiles-dev-setup-") as scratch:
    checkout = Path(scratch).resolve() / "checkout"
    home = Path(scratch).resolve() / "home"
    (checkout / "dev" / "scripts").mkdir(parents=True)
    (checkout / "lib").mkdir()
    (checkout / "dev" / "lib").mkdir()
    (home / ".local" / "bin").mkdir(parents=True)
    for name in ("install-dev-tools.sh", "install-hooks.sh", "run-mise.sh",
                 "format.sh", "lint.sh"):
        shutil.copy2(ROOT / "dev" / "scripts" / name, checkout / "dev" / "scripts" / name)
    for name in ("common.sh", "mise.sh"):
        shutil.copy2(ROOT / "lib" / name, checkout / "lib" / name)
    shutil.copy2(ROOT / "dev/lib/shell-files.sh", checkout / "dev/lib/shell-files.sh")
    (checkout / "dev/mise.toml").write_text("[tools]\n")
    (checkout / "sample.sh").write_text("#!/usr/bin/env bash\nprintf 'sample\\n'\n")
    subprocess.run(["git", "init", "-q", str(checkout)], check=True)
    subprocess.run(["git", "add", "sample.sh"], cwd=checkout, check=True)

    log = checkout / "mise-calls.log"
    hook = checkout / ".git" / "hooks" / "pre-commit"
    fake = home / ".local" / "bin" / "mise"
    fake.write_text("""#!/usr/bin/env bash
printf '%s\\n' "$*" >> "$MOCK_MISE_LOG"
case "$*" in
  install|which\\ *|exec\\ --\\ shfmt\\ *|exec\\ --\\ shellcheck\\ *) exit 0 ;;
  'exec -- lefthook check-install')
    [[ -x "$MOCK_HOOK" ]] && exit 0 || exit 1
    ;;
  'exec -- lefthook install pre-commit')
    cat >"$MOCK_HOOK" <<'HOOK'
#!/bin/sh
call_lefthook run "pre-commit" "$@"
HOOK
    chmod +x "$MOCK_HOOK"
    ;;
  *) exit 9 ;;
esac
""")
    fake.chmod(0o755)
    env = dict(os.environ)
    env.update({
        "HOME": str(home),
        "PATH": "/usr/bin:/bin",
        "MOCK_MISE_LOG": str(log),
        "MOCK_HOOK": str(hook),
        "GIT_CONFIG_GLOBAL": "/dev/null",
        "GIT_CONFIG_SYSTEM": "/dev/null",
    })
    script = str(checkout / "dev" / "scripts" / "install-dev-tools.sh")

    def quiet(args):
        return subprocess.run(args, cwd=checkout, env=env, stdin=subprocess.DEVNULL,
                              stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                              text=True, check=False, timeout=12)

    def tty(*answers):
        master, slave = pty.openpty()
        try:
            process = subprocess.Popen(["bash", script], cwd=checkout, env=env,
                                       stdin=slave, stdout=subprocess.PIPE,
                                       stderr=subprocess.STDOUT)
            out = communicate_confirmations(process, master, slave, *answers, timeout=12)
            return process.returncode, out
        finally:
            os.close(master)
            os.close(slave)

    # A checkout without shell activation can still install developer tools.
    result = quiet(["bash", script])
    assert result.returncode == 0, result.stdout
    assert "noninteractive stdin" in result.stdout, result.stdout
    assert "install" in log.read_text().splitlines(), log.read_text()
    assert not hook.exists()

    # Format/lint also resolve the pinned mise executable from ~/.local/bin.
    fmt = quiet(["bash", str(checkout / "dev" / "scripts" / "format.sh"), "--check"])
    lint = quiet(["bash", str(checkout / "dev" / "scripts" / "lint.sh")])
    assert fmt.returncode == 0, fmt.stdout
    assert lint.returncode == 0, lint.stdout
    calls = log.read_text()
    assert "exec -- shfmt -d -i 4 -- sample.sh" in calls, calls
    assert "exec -- shellcheck -x -- sample.sh" in calls, calls

    # Invoking the same setup interactively prompts once for the optional hook.
    declined, message = tty(Deny())
    assert declined == 0 and "Hook installation declined" in message, message
    assert not hook.exists(), message
    approved, message = tty(Confirm())
    assert approved == 0 and hook.is_file(), message
    assert "Enabled automatic shell formatting" in message, message
    assert log.read_text().count("exec -- lefthook install pre-commit") == 1

    # A repeated setup recognises an existing hook without asking or replacing it.
    before = hook.read_bytes()
    repeated, message = tty()
    assert repeated == 0 and "already installed" in message, message
    assert hook.read_bytes() == before
    assert log.read_text().count("exec -- lefthook install pre-commit") == 1

    # Tool wrapper gives a clear error when neither supported location exists.
    fake.unlink()
    missing = quiet(["bash", str(checkout / "dev" / "scripts" / "run-mise.sh"), "--version"])
    assert missing.returncode != 0 and "mise is unavailable" in missing.stdout

    print("PASS: Developer setup, mise fallback, optional hook consent and idempotence")
