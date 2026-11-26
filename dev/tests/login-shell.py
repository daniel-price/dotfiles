#!/usr/bin/env python3
"""No host account changes: fake id, getent, dscl, chsh and zsh via PATH."""
import os
import pty
import subprocess
import tempfile
from pathlib import Path

from confirmations import Confirm, Deny, communicate_confirmations

ROOT = Path(__file__).resolve().parents[2]
COMMON = ROOT / "src/lib/common.sh"
LIBRARY = ROOT / "src/lib/login-shell.sh"

with tempfile.TemporaryDirectory(prefix="dotfiles-login-shell-") as temporary:
    root = Path(temporary)
    bin_dir = root / "bin"
    home = root / "home"
    other_home = root / "other-home"
    bin_dir.mkdir()
    home.mkdir()
    other_home.mkdir()
    state = root / "account-shell"
    state.write_text("/bin/bash\n")
    log = root / "chsh.log"
    log.touch()
    registry = root / "shells"

    mocks = {
        "zsh": """#!/usr/bin/env bash
echo 'zsh 5.9 (fake)'
""",
        "id": """#!/usr/bin/env bash
case "$1" in -u) echo "¤{MOCK_UID:-1000}" ;; -un) echo testuser ;; *) exit 71 ;; esac
""",
        "getent": """#!/usr/bin/env bash
[[ "$1" == passwd && "$2" == testuser ]] || exit 72
[[ "¤{MOCK_GETENT_FAIL:-0}" == 0 ]] || exit 73
printf 'testuser:x:1000:1000:Test:%s:%s\n' "$MOCK_HOME" "$(cat "$MOCK_ACCOUNT_SHELL")"
""",
        "dscl": """#!/usr/bin/env bash
[[ "$1" == . && "$2" == -read && "$3" == /Users/testuser ]] || exit 74
case "$4" in
NFSHomeDirectory) echo "NFSHomeDirectory: $MOCK_HOME" ;;
UserShell) echo "UserShell: $(cat "$MOCK_ACCOUNT_SHELL")" ;;
*) exit 75 ;;
esac
""",
        "chsh": """#!/usr/bin/env bash
printf '%s\n' "$*" >> "$MOCK_CHSH_LOG"
[[ "$1" == -s && $# == 2 ]] || exit 76
[[ "¤{MOCK_CHSH_FAIL:-0}" == 0 ]] || exit 77
printf '%s\n' "$2" > "$MOCK_ACCOUNT_SHELL"
""",
    }
    for name, source in mocks.items():
        script = bin_dir / name
        script.write_text(source.replace("¤{", chr(36) + "{"))
        script.chmod(0o755)

    zsh_path = bin_dir / "zsh"
    registry.write_text("# supported shells\n/bin/bash\n" + str(zsh_path) + "\n")
    env = dict(os.environ, HOME=str(home), MOCK_HOME=str(home),
               MOCK_ACCOUNT_SHELL=str(state), MOCK_CHSH_LOG=str(log),
               PATH=str(bin_dir) + os.pathsep + os.environ["PATH"],
               TEST_SHELLS=str(registry), TEST_PLATFORM="debian",
               TEST_COMMON=str(COMMON), TEST_LIBRARY=str(LIBRARY))
    command = """source "$TEST_COMMON"
source "$TEST_LIBRARY"
offer_default_zsh "$TEST_PLATFORM" "$TEST_SHELLS"
"""

    def run(*, answer=None, overrides=None):
        context = {**env, **(overrides or {})}
        cmd = ["bash", "-c", command]
        if answer is None:
            return subprocess.run(cmd, cwd=root, env=context,
                                  stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                                  stderr=subprocess.STDOUT, text=True, timeout=10)
        master, slave = pty.openpty()
        try:
            process = subprocess.Popen(cmd, cwd=root, env=context, stdin=slave,
                                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            out = communicate_confirmations(process, master, slave, answer, timeout=10)
            return subprocess.CompletedProcess(cmd, process.returncode, out)
        finally:
            os.close(master)
            os.close(slave)

    unattended = run()
    assert unattended.returncode == 0 and "Declined" in unattended.stdout, unattended.stdout
    assert state.read_text() == "/bin/bash\n" and log.read_text() == ""

    declined = run(answer=Deny())
    assert declined.returncode == 0 and "Declined" in declined.stdout, declined.stdout
    assert not log.read_text()

    approved = run(answer=Confirm())
    assert approved.returncode == 0 and "changed to" in approved.stdout, approved.stdout
    assert state.read_text().strip() == str(zsh_path)
    assert log.read_text().strip() == f"-s {zsh_path}"

    repeated = run()
    assert repeated.returncode == 0 and "✓ Default login shell: Zsh" in repeated.stdout
    assert log.read_text().splitlines() == [f"-s {zsh_path}"]

    # macOS uses dscl rather than getent.
    state.write_text("/bin/bash\n")
    log.write_text("")
    macos = run(answer=Confirm(), overrides={"TEST_PLATFORM": "macos"})
    assert macos.returncode == 0 and "changed to" in macos.stdout, macos.stdout
    assert state.read_text().strip() == str(zsh_path)
    assert log.read_text().strip() == f"-s {zsh_path}"

    # Temporary HOME, root user, unreadable account and unregistered shell
    # must fail closed; no prompt or chsh action is allowed.
    state.write_text("/bin/bash\n")
    log.write_text("")
    assert "HOME differs" in run(overrides={"HOME": str(other_home)}).stdout
    assert "root" in run(overrides={"MOCK_UID": "0"}).stdout
    assert "could not read" in run(overrides={"MOCK_GETENT_FAIL": "1"}).stdout
    unlisted = root / "unlisted-shells"
    unlisted.write_text("/bin/bash\n")
    assert "not an executable Zsh entry" in run(overrides={"TEST_SHELLS": str(unlisted)}).stdout
    assert not log.read_text()

    failed = run(answer=Confirm(), overrides={"MOCK_CHSH_FAIL": "1"})
    assert failed.returncode != 0 and "chsh failed" in failed.stdout, failed.stdout
    assert state.read_text() == "/bin/bash\n"

    print("PASS: Zsh login shell consent, Linux/macOS account checks, idempotence, fail-closed behavior")
