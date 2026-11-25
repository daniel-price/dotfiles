#!/usr/bin/env python3
"""Mocked mise repository installer; never clones or changes the real HOME."""
import os
import pty
import subprocess
import tempfile
from pathlib import Path

from confirmations import Confirm, Deny, communicate_confirmations

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "src/lib/setup/setup-autosuggestions.sh"
MANIFEST = ROOT / "src/lib/setup/autosuggestions.toml"
declaration = MANIFEST.read_text()
assert "[bootstrap.repos]" in declaration
assert "https://github.com/zsh-users/zsh-autosuggestions.git" in declaration
assert "e52ee8ca55bcc56a17c828767a3f98f22a68d4eb" in declaration
assert "zsh-autosuggestions" not in (ROOT / "src/mise.toml").read_text()

with tempfile.TemporaryDirectory(prefix="dotfiles-test-autosuggestions-") as scratch:
    base = Path(scratch)
    home = base / "home"
    bin_dir = base / "bin"
    home.mkdir()
    bin_dir.mkdir()
    target = home / ".local/share/dotfiles/zsh-autosuggestions"
    log = base / "mise.log"
    log.touch()

    fake_id = bin_dir / "id"
    fake_id.write_text("""#!/usr/bin/env bash
[[ "$1" == -u ]] && echo "¤{MOCK_UID:-1000}"
""".replace("¤{", chr(36) + "{"))
    fake_id.chmod(0o755)

    fake_mise = bin_dir / "mise"
    fake_mise.write_text("""#!/usr/bin/env bash
if [[ "$1" == --version ]]; then echo '2026.11.9 fake'; exit 0; fi
printf '%s|%s\\n' "$MISE_GLOBAL_CONFIG_FILE" "$*" >> "$MOCK_LOG"
case "$*" in
"-C / bootstrap repos apply --dry-run") exit 0 ;;
"-C / bootstrap repos apply --yes")
    mkdir -p "$MOCK_PLUGIN/.git"
    touch "$MOCK_PLUGIN/zsh-autosuggestions.zsh"
    ;;
"-C / bootstrap repos status --missing")
    [[ -f "$MOCK_PLUGIN/zsh-autosuggestions.zsh" ]]
    ;;
*) exit 70 ;;
esac
""")
    fake_mise.chmod(0o755)
    env = dict(os.environ, HOME=str(home), PATH=str(bin_dir) + os.pathsep + os.environ["PATH"],
               MOCK_PLUGIN=str(target), MOCK_LOG=str(log),
               MISE_GLOBAL_CONFIG_FILE="/other/developer.toml")

    def run(args=(), answer=None, overrides=None):
        cmd = ["bash", str(SCRIPT), *args]
        context = dict(env, **(overrides or {}))
        if answer is None:
            return subprocess.run(cmd, env=context, cwd=base, stdin=subprocess.DEVNULL,
                                  stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                  text=True, timeout=12)
        master, slave = pty.openpty()
        try:
            proc = subprocess.Popen(cmd, cwd=base, env=context, stdin=slave,
                                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            output = communicate_confirmations(proc, master, slave, answer, timeout=12)
            return subprocess.CompletedProcess(cmd, proc.returncode, output)
        finally:
            os.close(master)
            os.close(slave)

    def calls():
        return log.read_text().splitlines()

    assert run(["--help"]).returncode == 0
    assert run(["--wat"]).returncode != 0
    assert run(["--apply", "--help"]).returncode != 0
    assert not calls()

    preview = run()
    assert preview.returncode == 0 and "Preview only" in preview.stdout, preview.stdout
    assert not target.exists()
    assert calls() == [str(MANIFEST) + "|-C / bootstrap repos apply --dry-run"], calls()

    log.write_text("")
    declined = run(["--apply"], answer=Deny())
    assert declined.returncode == 0 and "declined" in declined.stdout.lower()
    assert not target.exists()
    assert not any("apply --yes" in line for line in calls())

    log.write_text("")
    unattended = run(["--apply"])
    assert unattended.returncode == 0 and "declined" in unattended.stdout.lower()
    assert not target.exists()
    assert not any("apply --yes" in line for line in calls())

    log.write_text("")
    assert run(["--apply"], overrides={"MOCK_UID": "0"}).returncode != 0
    assert not calls()

    accepted = run(["--apply"], answer=Confirm())
    assert accepted.returncode == 0 and "installed" in accepted.stdout, accepted.stdout
    assert (target / "zsh-autosuggestions.zsh").exists()
    assert calls() == [
        str(MANIFEST) + "|-C / bootstrap repos apply --dry-run",
        str(MANIFEST) + "|-C / bootstrap repos apply --yes",
        str(MANIFEST) + "|-C / bootstrap repos status --missing",
    ], calls()

    log.write_text("")
    repeat = run(["--apply"])
    assert repeat.returncode == 0 and "already present" in repeat.stdout, repeat.stdout
    assert not any("apply" in x for x in calls())
    target.joinpath("zsh-autosuggestions.zsh").unlink()
    target.joinpath(".git").rmdir()
    target.rmdir()

    # A conflicting path must be preserved, with no clone attempt.
    target.mkdir(parents=True)
    (target / "README").write_text("user owned\n")
    conflict = run(["--apply"])
    assert conflict.returncode == 0 and "Preserving conflicting" in conflict.stdout
    assert (target / "README").read_text() == "user owned\n"

    print("PASS: Optional zsh-autosuggestions repo preview, consent, pin isolation, conflicts and repeatability")
