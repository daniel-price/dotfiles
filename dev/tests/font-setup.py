#!/usr/bin/env python3
"""Test optional font installation without network or changes to the real HOME."""
import os
import platform
import pty
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "setup/setup-fonts.sh"
GHOSTTY = ROOT / ".config/ghostty/config"
MANIFEST = ROOT / "setup/mise.toml"

assert "font-family = MesloLGS NF" in GHOSTTY.read_text()
assert '"~/.config/ghostty/config"' in MANIFEST.read_text()
assert "389133fb8c9a2347929a23702ce3039aacc46c3d" in SCRIPT.read_text()

with tempfile.TemporaryDirectory(prefix="dotfiles-test-fonts-") as scratch:
    base = Path(scratch)
    home = base / "home"
    mock_bin = base / "bin"
    home.mkdir()
    mock_bin.mkdir()
    calls = base / "downloads.log"
    calls.touch()
    scripts = {
        "id": '[[ "$1" == -u ]] && echo 1000',
        "uname": 'printf "%s\\n" "${MOCK_KERNEL:-Linux}"',
        "curl": '''
dest=''
url=''
while [[ $# -gt 0 ]]; do
    case "$1" in
    --output) dest=$2; shift 2 ;;
    http*) url=$1; shift ;;
    *) shift ;;
    esac
done
printf '%s\\n' "$url" >> "$MOCK_DOWNLOADS"
[[ "$url" == *'/389133fb8c9a2347929a23702ce3039aacc46c3d/'* ]] || exit 90
[[ "$url" != *"${MOCK_FAIL_FONT:-__none__}"* ]] || exit 91
if [[ "${MOCK_BAD_FONT:-0}" == 1 ]]; then
    printf 'bad' > "$dest"
else
    printf '\\000\\001\\000\\000fake-font' > "$dest"
fi
''',
        "fc-cache": 'exit 0',
    }
    for command, body in scripts.items():
        path = mock_bin / command
        path.write_text("#!/usr/bin/env bash\n" + body + "\n")
        path.chmod(0o755)

    env = dict(os.environ, HOME=str(home),
               PATH=str(mock_bin) + ":/usr/bin:/bin",
               MOCK_DOWNLOADS=str(calls), MOCK_KERNEL=platform.system())

    def run(*args, answer=None, **extra):
        command = ["bash", str(SCRIPT), *args]
        context = {**env, **extra}
        if answer is None:
            return subprocess.run(
                command, env=context, stdin=subprocess.DEVNULL,
                text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                timeout=15,
            )
        master, slave = pty.openpty()
        try:
            proc = subprocess.Popen(
                command, env=context, stdin=slave,
                stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            )
            os.close(slave)
            slave = -1
            os.write(master, answer.encode())
            output = proc.communicate(timeout=15)[0].decode(errors="replace")
            return subprocess.CompletedProcess(command, proc.returncode, output)
        finally:
            os.close(master)
            if slave != -1:
                os.close(slave)

    font_dir = home / ("Library/Fonts" if platform.system() == "Darwin" else ".local/share/fonts")
    names = [
        "MesloLGS NF Regular.ttf",
        "MesloLGS NF Bold.ttf",
        "MesloLGS NF Italic.ttf",
        "MesloLGS NF Bold Italic.ttf",
    ]
    assert run("--help").returncode == 0
    assert run("--bad").returncode != 0
    preview = run()
    assert preview.returncode == 0 and "Preview only" in preview.stdout
    assert not font_dir.exists() and not calls.read_text()
    denied = run("--apply", answer="n\n")
    assert denied.returncode == 0 and "declined" in denied.stdout.lower()
    assert not font_dir.exists() and not calls.read_text()
    unattended = run("--apply")
    assert unattended.returncode == 0 and not font_dir.exists()

    broken = run("--apply", answer="y\n", MOCK_FAIL_FONT="Italic")
    assert broken.returncode != 0, broken.stdout
    assert not font_dir.exists(), broken.stdout

    calls.write_text("")
    invalid = run("--apply", answer="y\n", MOCK_BAD_FONT="1")
    assert invalid.returncode != 0 and not font_dir.exists(), invalid.stdout

    calls.write_text("")
    accepted = run("--apply", answer="y\n")
    assert accepted.returncode == 0, accepted.stdout
    assert all((font_dir / name).is_file() for name in names)
    assert len(calls.read_text().splitlines()) == 4
    repeated = run("--apply")
    assert repeated.returncode == 0 and "already present" in repeated.stdout
    assert len(calls.read_text().splitlines()) == 4

    (font_dir / names[0]).unlink()
    foreign = base / "unrelated"
    foreign.write_text("leave me\n")
    (font_dir / names[0]).symlink_to(foreign)
    conflict = run("--apply", answer="y\n")
    assert conflict.returncode != 0 and "Conflicting font path" in conflict.stdout
    assert foreign.read_text() == "leave me\n"
    (font_dir / names[0]).unlink()
    (font_dir / names[0]).write_bytes(b"existing")

    mac = run("--apply", answer="y\n", MOCK_KERNEL="Darwin")
    assert mac.returncode == 0, mac.stdout
    assert all((home / "Library/Fonts" / name).is_file() for name in names)
    print("PASS: font preview, consent, immutable source, conflicts and OS paths")
