#!/usr/bin/env python3
"""Consent and checksum tests for pinned mise installation in bootstrap."""
import os
import platform
import pty
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "scripts" / "setup" / "bootstrap.sh"


def supported_host():
    if platform.system() == "Darwin":
        return True
    if platform.system() != "Linux":
        return False
    for release in (Path("/etc/os-release"), Path("/usr/lib/os-release")):
        if not release.is_file():
            continue
        fields = {}
        for line in release.read_text().splitlines():
            if "=" in line:
                key, value = line.split("=", 1)
                fields[key] = value.strip('"\'')
        return fields.get("ID") in {"debian", "ubuntu", "pop"} or any(
            name in fields.get("ID_LIKE", "").split()
            for name in ("debian", "ubuntu")
        )
    return False


if not supported_host():
    print("SKIP: pinned mise installer test (unsupported host)")
    raise SystemExit(0)

with tempfile.TemporaryDirectory(prefix="dotfiles-mise-installer-") as scratch:
    temp = Path(scratch)
    home = temp / "home"
    bin_dir = temp / "bin"
    home.mkdir()
    bin_dir.mkdir()
    log = temp / "actions.log"
    log.touch()

    (bin_dir / "zsh").write_text("#!/usr/bin/env bash\nexit 1\n")
    (bin_dir / "zsh").chmod(0o755)

    curl = bin_dir / "curl"
    curl.write_text("""#!/usr/bin/env bash
if [[ "$1" == --version ]]; then echo 'curl fake'; exit 0; fi
output=''
while [[ $# -gt 0 ]]; do
    case "$1" in
    --output) output=$2; shift 2 ;;
    *) shift ;;
    esac
done
[[ -n "$output" ]] || exit 2
echo 'download' >> "$MOCK_LOG"
cat > "$output" <<'INSTALLER'
#!/usr/bin/env sh
echo "installer:$MISE_VERSION:$MISE_INSTALL_PATH" >> "$MOCK_LOG"
mkdir -p "$(dirname "$MISE_INSTALL_PATH")"
cat > "$MISE_INSTALL_PATH" <<'MISE'
#!/usr/bin/env sh
if [ "$1" = --version ]; then echo '2026.11.9 fake'; fi
exit 0
MISE
chmod +x "$MISE_INSTALL_PATH"
INSTALLER
""")
    curl.chmod(0o755)

    for command in ("sha256sum", "shasum"):
        helper = bin_dir / command
        helper.write_text("""#!/usr/bin/env bash
file=${!#}
printf '%s  %s\n' "$MOCK_SHA256" "$file"
""")
        helper.chmod(0o755)

    env = dict(os.environ, HOME=str(home),
               PATH=str(bin_dir) + ":/usr/bin:/bin", MOCK_LOG=str(log),
               MOCK_SHA256="60adf5460b19a791b964c414a2fff9d46990c9f2b1dfc0e4ba8c2b865f882a2b")

    def run_tty(answers):
        master, slave = pty.openpty()
        try:
            process = subprocess.Popen(
                ["bash", str(SCRIPT)], cwd=temp, env=env, stdin=slave,
                stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            os.close(slave)
            slave = -1
            os.write(master, answers.encode())
            out = process.communicate(timeout=20)[0].decode(errors="replace")
            return process.returncode, out
        finally:
            os.close(master)
            if slave != -1:
                os.close(slave)

    target = home / ".local" / "bin" / "mise"
    refused = run_tty("n\n")
    assert refused[0] != 0 and not target.exists(), refused
    assert log.read_text() == "", log.read_text()

    env["MOCK_SHA256"] = "mismatch"
    mismatch = run_tty("y\n")
    assert mismatch[0] != 0 and "SHA-256 did not match" in mismatch[1], mismatch
    assert not target.exists()

    env["MOCK_SHA256"] = "60adf5460b19a791b964c414a2fff9d46990c9f2b1dfc0e4ba8c2b865f882a2b"
    accepted = run_tty("y\ny\nn\n")
    assert accepted[0] == 0, accepted
    assert target.exists(), accepted
    assert "installer:v2026.11.9:" in log.read_text(), log.read_text()
    before = log.read_text()
    repeated = subprocess.run(["bash", str(SCRIPT)], cwd=temp, env=env,
                              stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                              stderr=subprocess.STDOUT, text=True)
    assert repeated.returncode == 0, repeated.stdout
    assert "Existing mise 2026.11.9" in repeated.stdout
    assert log.read_text() == before, log.read_text()

    target.write_text("#!/usr/bin/env sh\necho '2026.8.15 fake'\n")
    target.chmod(0o755)
    old = subprocess.run(["bash", str(SCRIPT)], cwd=temp, env=env,
                         stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                         stderr=subprocess.STDOUT, text=True)
    assert old.returncode != 0 and "2026.11.9 or newer" in old.stdout, old.stdout
    assert log.read_text() == before
    print("PASS: Mise installer consent, checksum, existing version and repeatability")
