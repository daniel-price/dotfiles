#!/usr/bin/env python3
"""PTY tests for native mise-based package and tool provisioning."""
import os
import platform
import pty
import re
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "bin" / ",bootstrap"


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

    # Simulate an existing unrelated mapping: bootstrap must leave it alone.
    fake_hidutil = bin_dir / "hidutil"
    fake_hidutil.write_text("""#!/usr/bin/env bash
if [[ "$*" == "property --get UserKeyMapping" ]]; then
    echo '{ "UserKeyMapping": [{ "HIDKeyboardModifierMappingSrc": 1, "HIDKeyboardModifierMappingDst": 2 }] }'
else
    exit 1
fi
""")
    fake_hidutil.chmod(0o755)

    # This bootstrap test must never download real assets, even if a future
    # prompt accidentally receives approval from a misaligned PTY fixture.
    fake_curl = bin_dir / "curl"
    fake_curl.write_text("""#!/usr/bin/env bash
echo 'Unexpected network access in offline bootstrap fixture' >&2
exit 99
""")
    fake_curl.chmod(0o755)

    fake_mise = bin_dir / "mise"
    fake_mise.write_text("""#!/usr/bin/env bash
if [[ "$1" == --version ]]; then echo '2026.11.9 fake'; exit 0; fi
printf '%s|%s\\n' "$MISE_GLOBAL_CONFIG_FILE" "$*" >> "$MOCK_LOG"
[[ "$1" == -C && "$2" == / ]] || exit 20
shift 2
case "$*" in
  "bootstrap packages status --missing")
    [[ -e "$MOCK_STATE/zsh" && -e "$MOCK_STATE/ghostty" ]] || exit 1
    if [[ "$MOCK_LINUX" == 1 ]]; then
      [[ -e "$MOCK_STATE/wl-clipboard" ]] || exit 1
    fi
    ;;
  "bootstrap packages apply --dry-run") exit 0 ;;
  "bootstrap packages apply --yes")
    touch "$MOCK_STATE/zsh" "$MOCK_STATE/ghostty"
    if [[ "$MOCK_LINUX" == 1 ]]; then
      touch "$MOCK_STATE/wl-clipboard"
    fi
    ;;
  "bootstrap repos apply --dry-run") exit 0 ;;
  "bootstrap repos apply --yes")
    case "$MISE_GLOBAL_CONFIG_FILE" in
      */autosuggestions.toml)
        mkdir -p "$HOME/.local/share/dotfiles/zsh-autosuggestions/.git"
        : > "$HOME/.local/share/dotfiles/zsh-autosuggestions/zsh-autosuggestions.zsh"
        ;;
      */prompt.toml)
        mkdir -p "$HOME/.local/share/dotfiles/powerlevel10k/.git"
        : > "$HOME/.local/share/dotfiles/powerlevel10k/powerlevel10k.zsh-theme"
        ;;
      *) exit 22 ;;
    esac
    exit 0
    ;;
  "bootstrap repos status --missing")
    case "$MISE_GLOBAL_CONFIG_FILE" in
      */autosuggestions.toml)
        [[ -f "$HOME/.local/share/dotfiles/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]
        ;;
      */prompt.toml)
        [[ -f "$HOME/.local/share/dotfiles/powerlevel10k/powerlevel10k.zsh-theme" ]]
        ;;
      *) exit 22 ;;
    esac
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
  "dot status --missing")
    [[ -L "$HOME/.zshrc" && -L "$HOME/.config/zellij/config.kdl" && -L "$HOME/.config/ghostty/config" ]] && exit 0 || exit 1
    ;;
  "dot apply --dry-run --force") exit 0 ;;
  "dot apply --dry-run")
    # Model mise refusing to preview an existing unmanaged Zellij file.
    [[ ! -f "$HOME/.config/zellij/config.kdl" || -L "$HOME/.config/zellij/config.kdl" ]] || exit 17
    exit 0
    ;;
  "dot apply --yes")
    mkdir -p "$HOME/.config/zellij" "$HOME/.config/ghostty"
    [[ ! -e "$MOCK_STATE/fail-dot-apply" ]] || exit 18
    [[ ! -e "$HOME/.zshrc" || -L "$HOME/.zshrc" ]] || exit 17
    [[ ! -e "$HOME/.config/zellij/config.kdl" || -L "$HOME/.config/zellij/config.kdl" ]] || exit 17
    [[ ! -e "$HOME/.config/ghostty/config" || -L "$HOME/.config/ghostty/config" ]] || exit 17
    if [[ ! -e "$HOME/.zshrc" && ! -L "$HOME/.zshrc" ]]; then ln -s "$MOCK_DOT_SOURCE" "$HOME/.zshrc"; fi
    if [[ ! -e "$HOME/.config/zellij/config.kdl" && ! -L "$HOME/.config/zellij/config.kdl" ]]; then ln -s "$MOCK_ZELLIJ_SOURCE" "$HOME/.config/zellij/config.kdl"; fi
    if [[ ! -e "$HOME/.config/ghostty/config" && ! -L "$HOME/.config/ghostty/config" ]]; then ln -s "$MOCK_GHOSTTY_SOURCE" "$HOME/.config/ghostty/config"; fi
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
    for item in (ROOT / "setup/base-tools.toml").read_text().splitlines():
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
               MOCK_LINUX="1" if platform.system() == "Linux" else "0",
               MOCK_DOT_SOURCE=str(ROOT / ".config" / "zsh" / "zshrc"),
               MOCK_ZELLIJ_SOURCE=str(ROOT / ".config" / "zellij" / "config.kdl"),
               MOCK_GHOSTTY_SOURCE=str(ROOT / ".config" / "ghostty" / "config"),
               MOCK_TOOL_ROWS=tool_rows, MOCK_TOOL_PINS=tool_pins)

    def run(answers=None):
        if answers is None:
            return subprocess.run(["bash", str(SCRIPT), "--no-update"], cwd=base, env=env,
                                  stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                                  stderr=subprocess.STDOUT, text=True, check=False)
        master, slave = pty.openpty()
        try:
            proc = subprocess.Popen(["bash", str(SCRIPT), "--no-update"], cwd=base, env=env,
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
    declined = run("n\n" * (2 + len(pins)))
    assert declined.returncode == 0, declined.stdout
    assert not list(state.iterdir()), declined.stdout
    assert "Skipped OS package installation" in declined.stdout and "Skipped neovim" in declined.stdout
    assert "Zsh configuration: skipped (zsh unavailable)" in declined.stdout
    assert not any("dot apply --yes" in line for line in log.read_text().splitlines())
    assert not any("bootstrap packages apply --yes" in line for line in log.read_text().splitlines()), "Declining package consent must never install Ghostty or its PPA"

    # The two initial approvals are for the OS packages and mise-managed dotfiles.
    # Generate tool approvals from the manifest so adding a tool doesn't
    # silently approve it or hang an interactive test waiting for input.
    approved_tools = {"neovim", "zoxide"}
    answers = ["y", "y"] + [
        "y" if name in approved_tools else "n" for name in pins
    ]
    approved = run("\n".join(answers + ["n", "n", "n"]) + "\n")
    assert approved.returncode == 0, approved.stdout
    assert (state / "zsh").exists() and (state / "ghostty").exists() and (state / f"neovim@{pins['neovim']}").exists() and (state / f"zoxide@{pins['zoxide']}").exists(), (approved.stdout, log.read_text(), list(state.iterdir()), pins)
    if platform.system() == "Linux":
        assert (state / "wl-clipboard").exists(), approved.stdout
    assert all(
        not (state / f"{name}@{version}").exists()
        for name, version in pins.items() if name not in approved_tools
    )
    assert target.is_symlink() and target.resolve() == (ROOT / ".config/zsh/zshrc").resolve()
    zellij_target = home / ".config/zellij/config.kdl"
    assert zellij_target.is_symlink() and zellij_target.resolve() == (ROOT / ".config/zellij/config.kdl").resolve()
    ghostty_target = home / ".config/ghostty/config"
    assert ghostty_target.is_symlink() and ghostty_target.resolve() == (ROOT / ".config/ghostty/config").resolve()
    assert any(line.endswith("bootstrap packages apply --yes") for line in log.read_text().splitlines()), log.read_text()
    assert "Zsh configuration: applied" in approved.stdout
    calls = log.read_text().splitlines()
    assert any("dot apply --dry-run" in line for line in calls)
    assert sum(line.endswith("dot apply --yes") for line in calls) == 1
    assert next(i for i, line in enumerate(calls) if line.endswith("dot apply --yes")) < next(
        i for i, line in enumerate(calls) if line.endswith(f"install neovim@{pins['neovim']}")
    ), calls
    assert any(line.endswith(f"install zoxide@{pins['zoxide']}") for line in calls), calls
    assert any(line.endswith(f"install neovim@{pins['neovim']}") for line in calls), calls
    assert all(line.startswith(str(ROOT / "setup/mise.toml") + "|-C /")
               for line in calls if "bootstrap repos" not in line), calls
    optional_repo_manifests = (
        str(ROOT / "setup/prompt.toml"),
        str(ROOT / "setup/autosuggestions.toml"),
    )
    assert all(any(line.startswith(manifest + "|-C /") for manifest in optional_repo_manifests)
               for line in calls if "bootstrap repos" in line), calls
    assert any(line.startswith(str(ROOT / "setup/autosuggestions.toml") + "|-C / bootstrap repos apply --dry-run")
               for line in calls), calls
    assert any(line.endswith("bootstrap repos apply --dry-run") for line in calls), calls
    assert not any("scripts/dev" in line for line in calls), calls

    dot_before_repeat = sum("dot apply --yes" in line for line in log.read_text().splitlines())
    packages_before_repeat = sum("bootstrap packages apply --yes" in line for line in log.read_text().splitlines())
    zoxide_before_repeat = sum(line.endswith(f"install zoxide@{pins['zoxide']}") for line in calls)
    repeated = run()
    assert repeated.returncode == 0, repeated.stdout
    assert "Zsh configuration: applied" in repeated.stdout
    assert sum("dot apply --yes" in line for line in log.read_text().splitlines()) == dot_before_repeat
    assert sum("bootstrap packages apply --yes" in line for line in log.read_text().splitlines()) == packages_before_repeat
    assert sum(line.endswith(f"install zoxide@{pins['zoxide']}") for line in log.read_text().splitlines()) == zoxide_before_repeat
    assert not (state / f"zellij@{pins['zellij']}").exists(), repeated.stdout
    for name, version in pins.items():
        if name not in approved_tools:
            assert f"Skipped {name}@{version}" in repeated.stdout, repeated.stdout

    remaining = [
        (name, version) for name, version in pins.items()
        if not (state / f"{name}@{version}").exists()
    ]
    final = run("y\n" * len(remaining) + "n\nn\nn\n")
    assert final.returncode == 0, final.stdout
    assert (state / f"zellij@{pins['zellij']}").exists()
    assert "Bootstrap complete" in final.stdout
    assert all((state / f"{name}@{version}").exists() for name, version in pins.items())

    # Prompt is offered separately, after machine tools, with one approval.
    prompt_target = home / ".local/share/dotfiles/powerlevel10k"
    assert not prompt_target.exists()
    theme_approved = run("y\nn\nn\n")
    assert theme_approved.returncode == 0, theme_approved.stdout
    assert (prompt_target / "powerlevel10k.zsh-theme").exists()
    # Font offer is tied to active Zsh prompt config, not a Ghostty executable.
    assert "Download and install 4 missing font" in theme_approved.stdout, theme_approved.stdout
    assert any(line.startswith(str(ROOT / "setup/prompt.toml") + "|-C / bootstrap repos apply --yes")
               for line in log.read_text().splitlines()), log.read_text()
    # The second optional plugin has separate consent, and repeated installs are skipped.
    plugin_target = home / ".local/share/dotfiles/zsh-autosuggestions"
    assert not plugin_target.exists()
    plugin_approved = run("n\ny\n")
    assert plugin_approved.returncode == 0, plugin_approved.stdout
    assert (plugin_target / "zsh-autosuggestions.zsh").exists()
    assert any(line.startswith(str(ROOT / "setup/autosuggestions.toml") + "|-C / bootstrap repos apply --yes")
               for line in log.read_text().splitlines()), log.read_text()
    before_prompt_repeat = sum("bootstrap repos apply --yes" in line for line in log.read_text().splitlines())
    prompt_repeat = run()
    assert prompt_repeat.returncode == 0
    assert sum("bootstrap repos apply --yes" in line for line in log.read_text().splitlines()) == before_prompt_repeat

    # An existing regular Zellij config is preserved and replaced with the
    # managed symlink after explicit approval. Repeated runs create no backups.
    zellij_target.unlink()
    zellij_target.write_text("existing default zellij config\n")
    before_backups = list(zellij_target.parent.glob("config.kdl.backup-*"))
    migrated = run("y\n" + "n\n" * (len(pins) + 2))
    assert migrated.returncode == 0, migrated.stdout
    assert any(line.endswith("dot apply --dry-run --force") for line in log.read_text().splitlines())
    backups = list(zellij_target.parent.glob("config.kdl.backup-*"))
    assert len(backups) == len(before_backups) + 1, backups
    assert backups[-1].read_text() == "existing default zellij config\n"
    assert zellij_target.is_symlink() and zellij_target.resolve() == (ROOT / ".config/zellij/config.kdl").resolve()
    run()
    assert len(list(zellij_target.parent.glob("config.kdl.backup-*"))) == len(backups)

    # A failed mise apply restores the moved regular file, retaining its data.
    zellij_target.unlink()
    zellij_target.write_text("restore me\n")
    (state / "fail-dot-apply").touch()
    failed = run("y\n" + "n\n" * (len(pins) + 2))
    assert failed.returncode == 0, failed.stdout
    assert zellij_target.is_file() and not zellij_target.is_symlink()
    assert zellij_target.read_text() == "restore me\n"
    assert "Restored original Zellij config" in failed.stdout
    (state / "fail-dot-apply").unlink()
    zellij_target.unlink()
    zellij_target.symlink_to(ROOT / ".config/zellij/config.kdl")

    # Foreign symlinks are left untouched, never forcibly repointed.
    foreign_kdl = base / "foreign.kdl"
    foreign_kdl.write_text("custom config\n")
    zellij_target.unlink()
    zellij_target.symlink_to(foreign_kdl)
    # A foreign symlink is deliberately not replaceable, so it must not
    # receive a 'yes' that could accidentally approve the later font prompt.
    foreign = run("n\n" * (len(pins) + 3))
    assert foreign.returncode == 0, foreign.stdout
    assert zellij_target.is_symlink() and zellij_target.resolve() == foreign_kdl.resolve()
    assert "foreign symlink" in foreign.stdout
    zellij_target.unlink()
    zellij_target.symlink_to(ROOT / ".config/zellij/config.kdl")

    # An unrelated ~/.zshrc must not abort the remaining tool setup.
    target.unlink()
    target.write_text("personal shell setup\\n")
    before = len(log.read_text().splitlines())
    conflict = run()
    assert conflict.returncode == 0, conflict.stdout
    assert "Zsh configuration: not applied" in conflict.stdout
    assert target.read_text() == "personal shell setup\\n"
    assert not any("dot apply --yes" in line for line in log.read_text().splitlines()[before:])
    target.unlink()

    other = base / "other.zshrc"
    other.write_text("foreign symlink target\\n")
    target.symlink_to(other)
    conflict_link = run()
    assert conflict_link.returncode == 0, conflict_link.stdout
    assert target.is_symlink() and target.resolve() == other.resolve()
    assert "Zsh configuration: not applied" in conflict_link.stdout
    target.unlink()

    # Noninteractive runs preview the safe deployment but never approve it.
    before = len(log.read_text().splitlines())
    unattended = run()
    assert unattended.returncode == 0, unattended.stdout
    assert not target.exists()
    assert "Zsh configuration: not applied" in unattended.stdout
    assert any("dot apply --dry-run" in line for line in log.read_text().splitlines()[before:])
    assert not any(line.endswith("dot apply --yes") for line in log.read_text().splitlines()[before:])

    # An earlier mise cannot safely run the new bootstrap phases.
    fake_mise.write_text("#!/usr/bin/env bash\necho '2026.8.15 fake'\n")
    old = run()
    assert old.returncode != 0, old.stdout
    assert "2026.11.9 or newer" in old.stdout, old.stdout
    print("PASS: Native mise packages, Zsh/Zellij dotfiles, consent and tools")
