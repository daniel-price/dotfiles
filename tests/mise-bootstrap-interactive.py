#!/usr/bin/env python3
"""PTY tests for native mise-based package and tool provisioning."""
import os
import platform
import pty
import re
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
printf '%s|%s\\n' "$MISE_GLOBAL_CONFIG_FILE" "$*" >> "$MOCK_LOG"
[[ "$1" == -C && "$2" == / ]] || exit 20
shift 2
case "$*" in
  "bootstrap --only packages --dry-run") exit 0 ;;
  "bootstrap --only packages") touch "$MOCK_STATE/zsh"; exit 0 ;;
  "bootstrap repos apply --dry-run") exit 0 ;;
  "bootstrap repos apply --yes")
    mkdir -p "$HOME/.local/share/dotfiles/powerlevel10k/.git"
    : > "$HOME/.local/share/dotfiles/powerlevel10k/powerlevel10k.zsh-theme"
    exit 0
    ;;
  "bootstrap repos status --missing")
    [[ -f "$HOME/.local/share/dotfiles/powerlevel10k/powerlevel10k.zsh-theme" ]]
    ;;
  "ls --current --no-header --no-truncate")
    printf '%s\\n' "$MOCK_TOOL_ROWS"
    ;;
  "config get --file "*)
    key="${!#}"
    tool="${key#tools.}"
    tool="${tool#\\\"}"
    tool="${tool%\\\"}"
    while IFS='=' read -r name version; do
      if [[ "$name" == "$tool" ]]; then
        printf '%s\\n' "$version"
        exit 0
      fi
    done <<< "$MOCK_TOOL_PINS"
    exit 9
    ;;
  "install --dry-run-code "*)
    spec="$3"
    [[ -e "$MOCK_STATE/$spec" ]] && exit 0 || exit 1
    ;;
  "install "*)
    spec="$2"
    touch "$MOCK_STATE/$spec"
    ;;
  "dot diff"|"dot apply --dry-run") exit 0 ;;
  "dot apply")
    ln -s "$MOCK_DOT_SOURCE" "$HOME/.zshrc"
    exit 0
    ;;
  *) exit 21 ;;
esac
""")
    fake_mise.chmod(0o755)
    # Fake mise enumerates checked-in [tools] declarations; tests never need
    # an extra named-tool fixture when a new tool is added.
    pins = {}
    within_tools = False
    for item in (ROOT / "scripts/setup/mise.toml").read_text().splitlines():
        if item.strip() == "[tools]":
            within_tools = True
            continue
        if item.startswith("["):
            within_tools = False
        if within_tools:
            match = re.fullmatch(r'([A-Za-z0-9_-]+)\s*=\s*"([^"]+)"', item.strip())
            if match:
                pins[match.group(1)] = match.group(2)
    assert pins, "machine manifest missing tool declarations"
    tool_rows = "\n".join(f"{name} {version} (missing)" for name, version in pins.items())
    tool_pins = "\n".join(f"{name}={version}" for name, version in pins.items())

    env = dict(os.environ, HOME=str(home), PATH=str(bin_dir) + ":/usr/bin:/bin",
               MOCK_STATE=str(state), MOCK_LOG=str(log),
               MOCK_DOT_SOURCE=str(ROOT / ".config" / "zsh" / "zshrc"),
               MOCK_TOOL_ROWS=tool_rows, MOCK_TOOL_PINS=tool_pins)

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

    target = home / ".zshrc"

    # Each component requires its own approval. Declines are safe.
    declined = run("n\n" * (1 + len(pins)))
    assert declined.returncode == 0, declined.stdout
    assert not list(state.iterdir()), declined.stdout
    assert "Skipped zsh" in declined.stdout and "Skipped neovim" in declined.stdout
    assert "Zsh configuration: skipped (zsh unavailable)" in declined.stdout
    assert not any("dot " in line for line in log.read_text().splitlines())

    # The two initial approvals are for Zsh and its reviewed symlink.
    # Generate tool approvals from the manifest so adding a tool doesn't
    # silently approve it or hang an interactive test waiting for input.
    approved_tools = {"neovim", "zoxide"}
    answers = ["y", "y"] + [
        "y" if name in approved_tools else "n" for name in pins
    ]
    approved = run("\n".join(answers + ["n"]) + "\n")
    assert approved.returncode == 0, approved.stdout
    assert (state / "zsh").exists() and (state / f"neovim@{pins['neovim']}").exists() and (state / f"zoxide@{pins['zoxide']}").exists(), (approved.stdout, log.read_text(), list(state.iterdir()), pins)
    assert all(
        not (state / f"{name}@{version}").exists()
        for name, version in pins.items() if name not in approved_tools
    )
    assert target.is_symlink() and target.resolve() == (ROOT / ".config/zsh/zshrc").resolve()
    assert "Zsh configuration: applied" in approved.stdout
    calls = log.read_text().splitlines()
    assert any("dot apply --dry-run" in line for line in calls)
    assert sum(line.endswith("dot apply") for line in calls) == 1
    assert next(i for i, line in enumerate(calls) if line.endswith("dot apply")) < next(
        i for i, line in enumerate(calls) if line.endswith(f"install neovim@{pins['neovim']}")
    ), calls
    assert any(line.endswith(f"install zoxide@{pins['zoxide']}") for line in calls), calls
    assert any(line.endswith(f"install neovim@{pins['neovim']}") for line in calls), calls
    assert all(line.startswith(str(ROOT / "scripts/setup/mise.toml") + "|-C /")
               for line in calls if "bootstrap repos" not in line), calls
    assert all(line.startswith(str(ROOT / "scripts/setup/prompt.toml") + "|-C /")
               for line in calls if "bootstrap repos" in line), calls
    assert any(line.endswith("bootstrap repos apply --dry-run") for line in calls), calls
    assert not any("scripts/dev" in line for line in calls), calls

    dot_before_repeat = sum("dot " in line for line in log.read_text().splitlines())
    zoxide_before_repeat = sum(line.endswith(f"install zoxide@{pins['zoxide']}") for line in calls)
    repeated = run()
    assert repeated.returncode == 0, repeated.stdout
    assert "Zsh configuration: already applied" in repeated.stdout
    assert sum("dot " in line for line in log.read_text().splitlines()) == dot_before_repeat
    assert sum(line.endswith(f"install zoxide@{pins['zoxide']}") for line in log.read_text().splitlines()) == zoxide_before_repeat
    assert not (state / f"zellij@{pins['zellij']}").exists(), repeated.stdout
    for name, version in pins.items():
        if name not in approved_tools:
            assert f"Skipped {name}@{version}" in repeated.stdout, repeated.stdout

    remaining = [
        (name, version) for name, version in pins.items()
        if not (state / f"{name}@{version}").exists()
    ]
    final = run("y\n" * len(remaining) + "n\n")
    assert final.returncode == 0, final.stdout
    assert (state / f"zellij@{pins['zellij']}").exists()
    assert "Bootstrap complete" in final.stdout
    assert all((state / f"{name}@{version}").exists() for name, version in pins.items())

    # Prompt is offered separately, after machine tools, with one approval.
    prompt_target = home / ".local/share/dotfiles/powerlevel10k"
    assert not prompt_target.exists()
    theme_approved = run("y\\n")
    assert theme_approved.returncode == 0, theme_approved.stdout
    assert (prompt_target / "powerlevel10k.zsh-theme").exists()
    assert any(line.startswith(str(ROOT / "scripts/setup/prompt.toml") + "|-C / bootstrap repos apply --yes")
               for line in log.read_text().splitlines()), log.read_text()
    before_prompt_repeat = sum("bootstrap repos apply --yes" in line for line in log.read_text().splitlines())
    prompt_repeat = run()
    assert prompt_repeat.returncode == 0
    assert sum("bootstrap repos apply --yes" in line for line in log.read_text().splitlines()) == before_prompt_repeat

    # An unrelated ~/.zshrc must not abort the remaining tool setup.
    target.unlink()
    target.write_text("personal shell setup\\n")
    before = len(log.read_text().splitlines())
    conflict = run()
    assert conflict.returncode == 0, conflict.stdout
    assert "Zsh configuration: skipped (existing ~/.zshrc conflict)" in conflict.stdout
    assert target.read_text() == "personal shell setup\\n"
    assert not any("dot " in line for line in log.read_text().splitlines()[before:])
    target.unlink()

    other = base / "other.zshrc"
    other.write_text("foreign symlink target\\n")
    target.symlink_to(other)
    conflict_link = run()
    assert conflict_link.returncode == 0, conflict_link.stdout
    assert target.is_symlink() and target.resolve() == other.resolve()
    assert "existing ~/.zshrc conflict" in conflict_link.stdout
    target.unlink()

    # Noninteractive runs preview the safe deployment but never approve it.
    before = len(log.read_text().splitlines())
    unattended = run()
    assert unattended.returncode == 0, unattended.stdout
    assert not target.exists()
    assert "Zsh configuration: declined or noninteractive" in unattended.stdout
    assert any("dot apply --dry-run" in line for line in log.read_text().splitlines()[before:])
    assert not any(line.endswith("dot apply") for line in log.read_text().splitlines()[before:])

    # An earlier mise cannot safely run the new bootstrap phases.
    fake_mise.write_text("#!/usr/bin/env bash\necho '2026.8.15 fake'\n")
    old = run()
    assert old.returncode != 0, old.stdout
    assert "2026.11.9 or newer" in old.stdout, old.stdout
    print("PASS: Native mise packages, early Zsh activation, conflict preservation and tools")
