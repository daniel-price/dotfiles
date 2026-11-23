#!/usr/bin/env python3
"""Synthetic optional Podman install tests. Never runs apt or real Podman."""
import os
import pty
import subprocess
import tempfile
from pathlib import Path

from confirmations import Confirm, Deny, communicate_confirmations

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "setup/setup-podman.sh"
MANIFEST = ROOT / "containers/podman/mise.toml"
assert '"apt:podman" = { os = "linux" }' in MANIFEST.read_text()
assert "apt:podman" not in (ROOT / "setup/mise.toml").read_text()

with tempfile.TemporaryDirectory(prefix="dotfiles-test-podman-") as tmp:
    base = Path(tmp)
    bin_dir = base / "bin"
    home = base / "home"
    bin_dir.mkdir()
    home.mkdir()
    # A synthetic PATH prevents accidentally finding an installed host Podman.
    for name in ("bash", "git", "dirname", "cp", "chmod"):
        target = next((p for p in (Path("/bin") / name, Path("/usr/bin") / name)
                       if p.exists()), None)
        assert target is not None, name
        (bin_dir / name).symlink_to(target)

    uname = bin_dir / "uname"
    uname.write_text('''#!/usr/bin/env bash
[[ "$1" == -s ]] && echo "${MOCK_KERNEL:-Linux}"
''')
    uid = bin_dir / "id"
    uid.write_text('''#!/usr/bin/env bash
[[ "$1" == -u ]] && echo "${MOCK_UID:-1000}"
''')
    for f in (uname, uid):
        f.chmod(0o755)

    fake_podman = base / "podman-template"
    fake_podman.write_text('''#!/usr/bin/env bash
case "$1" in
--version) echo "podman fake" ;;
info) echo "${MOCK_ROOTLESS:-true}" ;;
*) exit 77 ;;
esac
''')
    fake_podman.chmod(0o755)
    log = base / "mise.log"
    log.touch()
    mise = bin_dir / "mise"
    mise.write_text('''#!/usr/bin/env bash
if [[ "$1" == --version ]]; then echo "${MOCK_MISE_VERSION:-2026.11.9} fake"; exit 0; fi
printf '%s|%s\n' "$MISE_GLOBAL_CONFIG_FILE" "$*" >> "$MOCK_MISE_LOG"
[[ "$1" == -C && "$2" == / ]] || exit 54
case "$*" in
"-C / bootstrap --only packages --dry-run") exit 0 ;;
"-C / bootstrap --only packages")
    cp "$MOCK_PODMAN_TEMPLATE" "$MOCK_BIN/podman"
    chmod +x "$MOCK_BIN/podman"
    ;;
*) exit 55 ;;
esac
''')
    mise.chmod(0o755)
    env = dict(os.environ, HOME=str(home), PATH=str(bin_dir),
               MOCK_BIN=str(bin_dir), MOCK_PODMAN_TEMPLATE=str(fake_podman),
               MOCK_MISE_LOG=str(log), MISE_GLOBAL_CONFIG_FILE="/other/manifest.toml")

    def run(args=(), answer=None, overrides=None):
        cmd = ["bash", str(SCRIPT), *args]
        environ = dict(env, **(overrides or {}))
        if answer is None:
            return subprocess.run(cmd, cwd=base, env=environ,
                                  stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                                  stderr=subprocess.STDOUT, text=True, timeout=10)
        master, slave = pty.openpty()
        try:
            proc = subprocess.Popen(cmd, cwd=base, env=environ, stdin=slave,
                                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            output = communicate_confirmations(proc, master, slave, answer, timeout=10)
            return subprocess.CompletedProcess(cmd, proc.returncode, output)
        finally:
            os.close(master)
            os.close(slave)

    def calls():
        return log.read_text().splitlines()

    assert run(["--help"]).returncode == 0
    assert run(["--unexpected"]).returncode != 0
    assert run(["--apply", "--dry-run"]).returncode != 0
    assert not calls()

    preview = run()
    assert preview.returncode == 0 and "Preview only" in preview.stdout, preview.stdout
    assert calls() == [str(MANIFEST) + "|-C / bootstrap --only packages --dry-run"], calls()
    assert not (bin_dir / "podman").exists()

    log.write_text("")
    unattended = run(["--apply"])
    assert unattended.returncode == 0 and "Declined" in unattended.stdout
    assert len(calls()) == 1
    log.write_text("")
    assert run(["--apply"], overrides={"MOCK_KERNEL": "Darwin"}).returncode != 0
    assert run(["--apply"], overrides={"MOCK_UID": "0"}).returncode != 0
    assert run(["--apply"], overrides={"MOCK_MISE_VERSION": "2026.8.15"}).returncode != 0
    assert not calls()

    accepted = run(["--apply"], answer=Confirm())
    assert accepted.returncode == 0 and "ready in rootless mode" in accepted.stdout, accepted.stdout
    assert (bin_dir / "podman").exists()
    assert calls() == [str(MANIFEST) + "|-C / bootstrap --only packages --dry-run",
                       str(MANIFEST) + "|-C / bootstrap --only packages"], calls()

    log.write_text("")
    repeated = run(["--apply"])
    assert repeated.returncode == 0 and "already installed" in repeated.stdout
    assert not calls()
    rootful = run(overrides={"MOCK_ROOTLESS": "false"})
    assert rootful.returncode != 0 and "not running rootless" in rootful.stdout
    assert not calls()
    print("PASS: Optional Podman manifest, preview, consent, rootless, repeatability")
