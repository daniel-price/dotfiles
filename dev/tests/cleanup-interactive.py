#!/usr/bin/env python3
"""Synthetic manifest-driven cleanup tests; never touch the host environment."""
import os
import pty
import re
import subprocess
import tempfile
from pathlib import Path

from confirmations import Confirm, Deny, confirmation_keys

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "setup" / "cleanup.sh"
SOURCE = ROOT / ".config" / "zsh" / "zshrc"
MANIFEST = ROOT / "setup" / "mise.toml"
BASE_TOOLS = ROOT / "setup" / "base-tools.toml"


def declared_tools():
    # Fixture inventory follows the manifest, not a second list of tool names.
    tools = {}
    within = False
    for row in BASE_TOOLS.read_text().splitlines():
        if row.strip() == "[tools]":
            within = True
            continue
        if row.startswith("["):
            within = False
        if within:
            match = re.fullmatch(r'([A-Za-z0-9_-]+)\s*=\s*"([^"]+)"', row.strip())
            if match:
                tools[match.group(1)] = match.group(2)
    assert tools, "machine manifest has no tool declarations"
    return tools


pins = declared_tools()
with tempfile.TemporaryDirectory(prefix="dotfiles-cleanup-") as scratch:
    base = Path(scratch)
    home, bin_dir, state = (base / name for name in ("home", "bin", "installed"))
    for path in (home, bin_dir, state):
        path.mkdir()
    log = base / "mise.log"
    log.touch()

    mise = bin_dir / "mise"
    mise.write_text("""#!/usr/bin/env bash
if [[ "${1:-}" == --version ]]; then
    echo '2026.11.9 fake'
    exit 0
fi
printf '%s|%s\\n' "$MISE_GLOBAL_CONFIG_FILE" "$*" >> "$MOCK_LOG"
[[ "$1" == -C && "$2" == / ]] || exit 22
shift 2
case "$1" in
  ls)
    [[ "$2" == --current && "$3" == --no-header && "$4" == --no-truncate ]] || exit 24
    printf '%s\\n' "$MOCK_TOOL_ROWS"
    ;;
  config)
    [[ "$2" == get && "$3" == --file ]] || exit 24
    tool="${5#tools.}"
    tool="${tool#\\\"}"
    tool="${tool%\\\"}"
    if [[ "${MOCK_BAD_VERSION_TOOL:-}" == "$tool" ]]; then
      echo 'latest'
      exit 0
    fi
    while IFS='=' read -r name version; do
      [[ "$name" == "$tool" ]] || continue
      printf '%s\\n' "$version"
      exit 0
    done <<< "$MOCK_TOOL_PINS"
    exit 8
    ;;
  uninstall)
    if [[ "$2" == --dry-run-code ]]; then
      spec=$3
      [[ -e "$MOCK_STATE/$spec" ]] && exit 1 || exit 0
    elif [[ "$2" == --yes ]]; then
      rm -f -- "$MOCK_STATE/$3"
    else
      exit 25
    fi
    ;;
  dot)
    [[ "$2" == unapply ]] || exit 25
    if [[ "$3" == --yes ]]; then
      # Approximate mise's conservative unapply: only links to reviewed sources.
      if [[ -L "$HOME/.zshrc" && "$HOME/.zshrc" -ef "$MOCK_DOT_SOURCE" ]]; then rm -f -- "$HOME/.zshrc"; fi
      [[ -L "$HOME/.config/zellij/config.kdl" && "$HOME/.config/zellij/config.kdl" -ef "$MOCK_ZELLIJ_SOURCE" ]] && rm -f -- "$HOME/.config/zellij/config.kdl"
    elif [[ "$3" == --dry-run ]]; then
      :
    else
      exit 25
    fi
    ;;
  *) exit 23 ;;
esac
""")
    mise.chmod(0o755)
    env = dict(os.environ)
    env.update({
        "HOME": str(home),
        "PATH": str(bin_dir) + os.pathsep + "/usr/bin:/bin",
        "MOCK_LOG": str(log),
        "MOCK_STATE": str(state),
        "MOCK_DOT_SOURCE": str(SOURCE),
        "MOCK_ZELLIJ_SOURCE": str(ROOT / ".config/zellij/config.kdl"),
        "MOCK_TOOL_ROWS": "\n".join(
            f"{name} {version} (missing)" for name, version in pins.items()
        ),
        "MOCK_TOOL_PINS": "\n".join(
            f"{name}={version}" for name, version in pins.items()
        ),
    })
    target = home / ".zshrc"
    zellij_target = home / ".config/zellij/config.kdl"
    zellij_target.parent.mkdir(parents=True)
    zellij_target.symlink_to(ROOT / ".config/zellij/config.kdl")

    def run_quiet(args, input_text=None, overrides=None):
        return subprocess.run(
            ["bash", str(SCRIPT), *args], cwd=base, env={**env, **(overrides or {})},
            input=input_text,
            **({"stdin": subprocess.DEVNULL} if input_text is None else {}),
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
            check=False, timeout=12,
        )

    def run_tty(args, *answers):
        master, slave = pty.openpty()
        try:
            proc = subprocess.Popen(
                ["bash", str(SCRIPT), *args], cwd=base, env=env,
                stdin=slave, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            )
            os.close(slave)
            slave = -1
            # Send keypresses without Enter; confirmation consumes one key.
            os.write(master, confirmation_keys(*answers))
            output = proc.communicate(timeout=12)[0].decode(errors="replace")
            return proc.returncode, output
        finally:
            os.close(master)
            if slave != -1:
                os.close(slave)

    def operations():
        return [line.split("|", 1)[1] for line in log.read_text().splitlines()]

    def destructive():
        return [line for line in operations() if " --yes " in line or "unapply --yes" in line]

    def reset_log():
        log.write_text("")

    for name, version in pins.items():
        (state / f"{name}@{version}").touch()
    target.symlink_to(SOURCE)
    assert run_quiet(["--help"]).returncode == 0
    assert run_quiet(["--unknown"]).returncode != 0
    assert run_quiet(["--apply", "--yes"]).returncode != 0

    # The default must be a complete, read-only preview of exact pinned specs.
    preview = run_quiet([])
    assert preview.returncode == 0, preview.stdout
    assert "Preview only; no changes were made" in preview.stdout
    assert target.is_symlink() and zellij_target.is_symlink()
    assert all((state / f"{name}@{version}").exists() for name, version in pins.items())
    assert any("dot unapply --dry-run" in line for line in operations())
    for name, version in pins.items():
        assert f"-C / uninstall --dry-run-code {name}@{version}" in operations(), operations()
    assert not destructive(), operations()
    assert all(line.startswith(str(MANIFEST) + "|") for line in log.read_text().splitlines())

    # Piped approvals cannot remove anything.
    reset_log()
    piped = run_quiet(["--apply"], "yes\n" * (len(pins) + 1))
    assert piped.returncode == 0, piped.stdout
    assert target.is_symlink() and zellij_target.is_symlink() and not destructive(), operations()
    assert all((state / f"{name}@{version}").exists() for name, version in pins.items())

    # Unrelated shell files and foreign symlinks are never removed.
    target.unlink()
    unrelated = base / "personal-zsh"
    unrelated.write_text("my own configuration\n")
    target.symlink_to(unrelated)
    reset_log()
    foreign = run_quiet(["--apply"], "yes\n" * (len(pins) + 1))
    assert foreign.returncode == 0 and target.resolve() == unrelated.resolve()
    assert any("dot unapply --dry-run" in line for line in operations())
    target.unlink()
    target.write_text("custom config\n")
    reset_log()
    ordinary = run_quiet([])
    assert ordinary.returncode == 0 and target.read_text() == "custom config\n"
    assert any("dot unapply --dry-run" in line for line in operations())
    target.unlink()

    # Decline the symlink, approve the first declared tool, decline the rest.
    reset_log()
    target.symlink_to(SOURCE)
    first = next(iter(pins))
    answers = [Deny(), *(Confirm() if name == first else Deny() for name in pins)]
    code, out = run_tty(["--apply"], *answers)
    assert code == 0, out
    assert target.is_symlink() and zellij_target.is_symlink()
    assert not (state / f"{first}@{pins[first]}").exists()
    assert all((state / f"{name}@{version}").exists()
               for name, version in pins.items() if name != first)
    assert destructive() == [f"-C / uninstall --yes {first}@{pins[first]}"], operations()

    # Subsequent approval removes only the remaining declared versions.
    reset_log()
    remaining = [(name, version) for name, version in pins.items() if name != first]
    code, out = run_tty(["--apply"], *(Confirm() for _ in range(len(remaining) + 1)))
    assert code == 0, out
    assert not target.exists() and not zellij_target.exists()
    assert not any(state.iterdir())
    assert destructive() == [
        "-C / dot unapply --yes",
        *(f"-C / uninstall --yes {name}@{version}" for name, version in remaining),
    ], operations()

    reset_log()
    repeated = run_quiet(["--apply"])
    assert repeated.returncode == 0, repeated.stdout
    assert not destructive(), operations()

    # Malformed versions must fail *before* even a symlink removal is offered.
    target.symlink_to(SOURCE)
    reset_log()
    bad = run_quiet(["--apply"], overrides={"MOCK_BAD_VERSION_TOOL": first})
    assert bad.returncode != 0, bad.stdout
    assert "Refusing unpinned machine tool" in bad.stdout
    assert target.is_symlink() and not destructive(), operations()

    print("PASS: Manifest-driven cleanup previews, conflicts, exact pins, consent and reruns")
