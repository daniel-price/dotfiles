#!/usr/bin/env python3
"""PTY tests for native mise-based package and tool provisioning."""
import os
import platform
import pty
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "scripts" / "setup" / "bootstrap.sh"


def supported():
    if platform.system() == "Darwin":
        return True
    if platform.system() != "Linux":
        return False
    metadata = Path("/etc/os-release")
    if not metadata.exists():
        return False
    value = metadata.read_text()
    return any(s in value for s in ("ID=debian", "ID=ubuntu", "ID=pop", "ID_LIKE="))


if not supported():
    print("SKIP: native mise bootstrap (unsupported host)")
    raise SystemExit(0)

with tempfile.TemporaryDirectory(prefix="dotfiles-mise-native-") as scratch:
    base = Path(scratch)
    home = base / "home"
    bin_dir = base / "bin"
    state = base / "state"
    for directory in (home, bin_dir, state):
        directory.mkdir()
    log = base / "mise.log"
    log.touch()

    fake_zsh = bin_dir / "zsh"
    fake_zsh.write_text("""#!/usr/bin/env bash
[[ -e "$MOCK_STATE/zsh" ]] || exit 1
echo 'zsh fake'
""")
    fake_zsh.chmod(0o755)

    fake_mise = bin_dir / "mise"
    fake_mise.write_text("""#!/usr/bin/env bash
if [[ "$1" == --version ]]; then echo '2026.11.9 fake'; exit 0; fi
printf '%s|%s\n' "$MISE_GLOBAL_CONFIG_FILE" "$*" >> "$MOCK_LOG"
[[ "$1" == -C && "$2" == / ]] || exit 20
shift 2
case "$*" in
  "bootstrap --only packages --dry-run") exit 0 ;;
  "bootstrap --only packages") touch "$MOCK_STATE/zsh"; exit 0 ;;
  "install --dry-run-code neovim") [[ -e "$MOCK_STATE/neovim" ]] && exit 0 || exit 1 ;;
  "install --dry-run-code zellij") [[ -e "$MOCK_STATE/zellij" ]] && exit 0 || exit 1 ;;
  "install neovim") touch "$MOCK_STATE/neovim"; exit 0 ;;
  "install zellij") touch "$MOCK_STATE/zellij"; exit 0 ;;
  *) exit 21 ;;
esac
""")
    fake_mise.chmod(0o755)
    env = dict(os.environ, HOME=str(home), PATH=str(bin_dir) + ":/usr/bin:/bin",
               MOCK_STATE=str(state), MOCK_LOG=str(log))

    def run(answers=None):
        if answers is None:
            return subprocess.run(["bash", str(SCRIPT)], cwd=base, env=env,
                                  stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                                  stderr=subprocess.STDOUT, text=True, check=False)
        master, slave = pty.openpty()
        try:
            proc = subprocess.Popen(["bash", str(SCRIPT)], cwd=base, env=env,
                                    stdin=slave, stdout=subprocess.PIPE,
                                    stderr=subprocess.STDOUT)
            os.close(slave)
            slave = -1
            os.write(master, answers.encode())
            out = proc.communicate(timeout=20)[0].decode(errors="replace")
            return subprocess.CompletedProcess([], proc.returncode, out)
        finally:
            os.close(master)
            if slave != -1:
                os.close(slave)

    # Each component requires its own approval. Declines are safe.
    declined = run("n\nn\nn\n")
    assert declined.returncode == 0, declined.stdout
    assert not list(state.iterdir()), declined.stdout
    assert "Skipped zsh" in declined.stdout and "Skipped neovim" in declined.stdout

    approved = run("y\ny\nn\n")
    assert approved.returncode == 0, approved.stdout
    assert (state / "zsh").exists() and (state / "neovim").exists()
    assert not (state / "zellij").exists()
    calls = log.read_text().splitlines()
    assert all(line.startswith(str(ROOT / ".config/mise/config.toml") + "|-C /")
               for line in calls), calls
    assert not any("scripts/dev" in line for line in calls), calls

    repeated = run()
    assert repeated.returncode == 0, repeated.stdout
    assert not (state / "zellij").exists(), repeated.stdout
    assert "Skipped zellij" in repeated.stdout

    final = run("y\n")
    assert final.returncode == 0, final.stdout
    assert (state / "zellij").exists()
    assert "Bootstrap complete" in final.stdout

    # An earlier mise cannot safely run the new bootstrap phases.
    fake_mise.write_text("#!/usr/bin/env bash\necho '2026.8.15 fake'\n")
    old = run()
    assert old.returncode != 0, old.stdout
    assert "2026.11.9 or newer" in old.stdout, old.stdout
    print("PASS: Native mise packages/tools, approvals, isolated config, repeatability")
