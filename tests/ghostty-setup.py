#!/usr/bin/env python3
"""Mocked Ghostty desktop package install; no real HOME, PPA, or brew changes."""
import os
import pty
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts/setup/setup-ghostty.sh"
MANIFEST = ROOT / "scripts/setup/ghostty.toml"

declarations = MANIFEST.read_text()
assert 'ppa = "mkasberg/ghostty-ubuntu"' in declarations
assert '"apt:ghostty"' in declarations
assert '"brew-cask:ghostty"' in declarations
assert "ghostty" not in (ROOT / "scripts/setup/mise.toml").read_text().split("[bootstrap.packages]")[1].split("[dotfiles]")[0]

with tempfile.TemporaryDirectory(prefix="dotfiles-test-ghostty-") as scratch:
    base = Path(scratch)
    home = base / "home"
    fake_bin = base / "bin"
    home.mkdir()
    fake_bin.mkdir()
    log = base / "mise.log"
    log.touch()

    mocks = {
        "uname": 'printf "%s\\n" "${MOCK_KERNEL:-Darwin}"',
        "id": '[[ "$1" == -u ]] && echo "${MOCK_UID:-1000}"',
        "mise": r'''
if [[ "$1" == --version ]]; then
    echo '2026.11.9 fake'
    exit 0
fi
printf '%s|%s\n' "$MISE_GLOBAL_CONFIG_FILE" "$*" >> "$MOCK_LOG"
case "$*" in
  "-C / bootstrap packages apply --dry-run brew-cask:ghostty")
    [[ "${MOCK_FAIL_PREVIEW:-0}" != 1 ]]
    ;;
  "-C / bootstrap packages apply --yes brew-cask:ghostty")
    [[ "${MOCK_FAIL_INSTALL:-0}" != 1 ]] || exit 12
    mkdir -p "$HOME/Applications/Ghostty.app"
    ;;
  *) exit 77 ;;
esac
''',
    }
    for name, body in mocks.items():
        path = fake_bin / name
        path.write_text("#!/usr/bin/env bash\n" + body + "\n")
        path.chmod(0o755)

    env = dict(os.environ, HOME=str(home),
               PATH=str(fake_bin) + ":/usr/bin:/bin",
               MOCK_LOG=str(log), MOCK_KERNEL="Darwin")

    def run(*args, answer=None, **overrides):
        cmd = ["bash", str(SCRIPT), *args]
        context = {**env, **overrides}
        if answer is None:
            return subprocess.run(
                cmd, cwd=base, env=context,
                stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT, text=True, timeout=15,
            )
        master, slave = pty.openpty()
        try:
            proc = subprocess.Popen(
                cmd, cwd=base, env=context, stdin=slave,
                stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            )
            os.close(slave)
            slave = -1
            os.write(master, answer.encode())
            output = proc.communicate(timeout=15)[0].decode(errors="replace")
            return subprocess.CompletedProcess(cmd, proc.returncode, output)
        finally:
            os.close(master)
            if slave != -1:
                os.close(slave)

    app = home / "Applications/Ghostty.app"
    assert run("--help").returncode == 0
    assert run("--unexpected").returncode != 0
    assert not log.read_text()

    preview = run()
    assert preview.returncode == 0 and "Preview only" in preview.stdout, preview.stdout
    assert not app.exists()
    assert log.read_text().splitlines() == [
        str(MANIFEST) + "|-C / bootstrap packages apply --dry-run brew-cask:ghostty"
    ]

    log.write_text("")
    declined = run("--apply", answer="n\n")
    assert declined.returncode == 0 and "declined" in declined.stdout.lower(), declined.stdout
    assert not app.exists()
    assert not any("--yes" in x for x in log.read_text().splitlines())

    unattended = run("--apply")
    assert unattended.returncode == 0 and not app.exists()
    assert not any("--yes" in x for x in log.read_text().splitlines())

    failed_preview = run("--apply", answer="y\n", MOCK_FAIL_PREVIEW="1")
    assert failed_preview.returncode != 0 and not app.exists()

    failed_install = run("--apply", answer="y\n", MOCK_FAIL_INSTALL="1")
    assert failed_install.returncode != 0 and not app.exists()

    log.write_text("")
    accepted = run("--apply", answer="y\n")
    assert accepted.returncode == 0 and app.is_dir(), accepted.stdout
    assert log.read_text().splitlines() == [
        str(MANIFEST) + "|-C / bootstrap packages apply --dry-run brew-cask:ghostty",
        str(MANIFEST) + "|-C / bootstrap packages apply --yes brew-cask:ghostty",
    ]

    log.write_text("")
    repeated = run("--apply")
    assert repeated.returncode == 0 and "already exists" in repeated.stdout, repeated.stdout
    assert not log.read_text(), "already installed app must not trigger package management"

    unsupported = run("--apply", MOCK_KERNEL="Linux")
    assert unsupported.returncode == 0
    assert "skipping" in unsupported.stdout.lower() or "Ghostty PPA" in unsupported.stdout
    assert not log.read_text()

print("PASS: optional Ghostty mise preview, approval, platform scope, conflicts and repeat")
