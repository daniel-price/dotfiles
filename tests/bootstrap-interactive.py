#!/usr/bin/env python3
"""PTY-backed tests for bootstrap prerequisite consent and idempotency."""
import os
import platform
import pty
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "scripts" / "bootstrap.sh"


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
    print("SKIP: bootstrap prerequisite PTY tests (unsupported host)")
    raise SystemExit(0)


with tempfile.TemporaryDirectory(prefix="dotfiles-bootstrap-prerequisites-") as scratch:
    temp = Path(scratch)
    bin_dir = temp / "bin"
    home = temp / "home"
    state = temp / "state"
    bin_dir.mkdir()
    home.mkdir()
    state.mkdir()
    log = temp / "installs"

    for tool in ("zsh",):
        executable = bin_dir / tool
        executable.write_text("""#!/usr/bin/env bash
tool=${0##*/}
[[ -e "$MOCK_STATE/$tool" ]] || exit 1
printf '%s fake\\n' "$tool"
""")
        executable.chmod(0o755)

    curl = bin_dir / "curl"
    curl.write_text("""#!/usr/bin/env bash
if [[ "${1:-}" == --version ]]; then
    [[ -e "$MOCK_STATE/curl" ]] || exit 1
    printf 'curl fake\\n'
    exit 0
fi
output=''
while [[ $# -gt 0 ]]; do
    case "$1" in
    --output)
        output=$2
        shift 2
        ;;
    *) shift ;;
    esac
done
[[ -n "$output" ]] || exit 2
printf 'curl-download:%s\\n' "$output" >> "$MOCK_INSTALL_LOG"
cat > "$output" <<'INSTALLER'
#!/usr/bin/env sh
printf 'installer:%s:%s\\n' "$MISE_VERSION" "$MISE_INSTALL_PATH" >> "$MOCK_INSTALL_LOG"
mkdir -p "$(dirname "$MISE_INSTALL_PATH")"
cat > "$MISE_INSTALL_PATH" <<'MISE'
#!/usr/bin/env sh
printf '%s fake\\n' "$MOCK_MISE_VERSION"
MISE
chmod +x "$MISE_INSTALL_PATH"
INSTALLER
""")
    curl.chmod(0o755)

    apt_get = bin_dir / "apt-get"
    apt_get.write_text("""#!/usr/bin/env bash
printf '%s:%s\\n' "${0##*/}" "$*" >> "$MOCK_INSTALL_LOG"
tool=${!#}
touch "$MOCK_STATE/$tool"
""")
    apt_get.chmod(0o755)

    brew = bin_dir / "brew"
    brew.write_text("""#!/usr/bin/env bash
printf '%s:%s\\n' "${0##*/}" "$*" >> "$MOCK_INSTALL_LOG"
case "$1" in
  list)
    [[ -e "$MOCK_STATE/ghostty" ]] || exit 1
    ;;
  install)
    tool=${!#}
    touch "$MOCK_STATE/$tool"
    ;;
esac
""")
    brew.chmod(0o755)

    apt_cache = bin_dir / "apt-cache"
    apt_cache.write_text("""#!/usr/bin/env bash
printf '%s\\n' '  Candidate: 1.4.0'
""")
    apt_cache.chmod(0o755)

    dpkg_query = bin_dir / "dpkg-query"
    dpkg_query.write_text("""#!/usr/bin/env bash
if [[ -e "$MOCK_GHOSTTY_STATE" ]]; then
  printf '%s\\n' 'install ok installed'
else
  printf '%s\\n' 'deinstall ok config-files'
fi
""")
    dpkg_query.chmod(0o755)

    add_repo = bin_dir / "add-apt-repository"
    add_repo.write_text("""#!/usr/bin/env bash
printf '%s:%s\\n' "${0##*/}" "$*" >> "$MOCK_INSTALL_LOG"
""")
    add_repo.chmod(0o755)

    sudo = bin_dir / "sudo"
    sudo.write_text("""#!/usr/bin/env bash
exec "$@"
""")
    sudo.chmod(0o755)

    for checksum_tool in ("sha256sum", "shasum"):
        executable = bin_dir / checksum_tool
        executable.write_text("""#!/usr/bin/env bash
file=${!#}
printf '%s  %s\\n' "$MOCK_INSTALLER_SHA256" "$file"
""")
        executable.chmod(0o755)

    env = dict(os.environ)
    env.update({
        "HOME": str(home),
        "PATH": str(bin_dir) + os.pathsep + "/usr/bin:/bin",
        "MOCK_INSTALL_LOG": str(log),
        "MOCK_INSTALLER_SHA256": "60adf5460b19a791b964c414a2fff9d46990c9f2b1dfc0e4ba8c2b865f882a2b",
        "MOCK_MISE_VERSION": "2026.11.9",
        "MOCK_STATE": str(state),
        "MOCK_GHOSTTY_STATE": str(state / "ghostty"),
        "MOCK_COMMAND_LOG": str(temp / "ghostty-commands.log"),
    })

    def run_tty(answers):
        master, slave = pty.openpty()
        try:
            process = subprocess.Popen(
                ["bash", str(SCRIPT)],
                stdin=slave, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                cwd=temp, env=env,
            )
            os.close(slave)
            slave = -1
            os.write(master, answers.encode())
            output = process.communicate(timeout=12)[0].decode(errors="replace")
            return process.returncode, output
        finally:
            os.close(master)
            if slave != -1:
                os.close(slave)

    # Refusing zsh does not block a separately approved curl installation.
    status, output = run_tty("n\ny\nn\nn\n")
    assert status == 0, output
    assert not (state / "zsh").exists(), output
    assert (state / "curl").exists(), output
    assert "Skipped zsh installation" in output, output

    log.unlink()
    (state / "curl").unlink()
    status, output = run_tty("y\ny\nn\nn\n")
    assert status == 0, output
    assert (state / "zsh").exists() and (state / "curl").exists(), output
    installs = log.read_text().splitlines()
    if platform.system() == "Linux":
        expected = ["apt-get:install --no-upgrade zsh", "apt-get:install --no-upgrade curl"]
    else:
        expected = ["brew:install zsh", "brew:install curl"]
    assert installs == expected, installs

    # A repeat run does not prompt for available tools or invoke apt/Homebrew.
    result = subprocess.run(
        ["bash", str(SCRIPT)],
        cwd=temp, env=env, stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, check=False,
    )
    assert result.returncode == 0, result.stdout
    assert "no installation needed" in result.stdout, result.stdout
    assert log.read_text().splitlines() == expected, log.read_text()

    target = home / ".local" / "bin" / "mise"
    target.parent.mkdir(parents=True)
    target.write_text("#!/usr/bin/env sh\nprintf '2026.8.15 fake\\n'\n")
    target.chmod(0o755)
    result = subprocess.run(
        ["bash", str(SCRIPT)],
        cwd=temp, env=env, stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, check=False,
    )
    assert result.returncode == 0, result.stdout
    assert "Existing mise 2026.8.15" in result.stdout, result.stdout
    assert log.read_text().splitlines() == expected, log.read_text()
    target.unlink()

    env["MOCK_INSTALLER_SHA256"] = "mismatch"
    status, output = run_tty("y\n")
    assert status != 0, output
    assert "SHA-256 did not match" in output, output
    assert not target.exists(), output
    assert "installer:" not in log.read_text(), log.read_text()

    env["MOCK_INSTALLER_SHA256"] = "60adf5460b19a791b964c414a2fff9d46990c9f2b1dfc0e4ba8c2b865f882a2b"
    log.unlink()
    status, output = run_tty("y\ny\ny\n")
    assert status == 0, output
    assert target.is_file(), output
    installs = log.read_text().splitlines()
    assert len(installs) >= 2 and installs[0].startswith("curl-download:"), installs
    assert installs[1] == f"installer:v2026.11.9:{target}", installs
    assert installs[2] == "apt-get:install ghostty", installs

    # The pinned installation is then skipped without downloading or updating it.
    result = subprocess.run(
        ["bash", str(SCRIPT)],
        cwd=temp, env=env, stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, check=False,
    )
    assert result.returncode == 0, result.stdout
    assert "Existing mise 2026.11.9" in result.stdout, result.stdout
    assert log.read_text().splitlines() == installs, log.read_text()

    print("PASS: Bootstrap prerequisite and mise consent, verification and repeatability")
