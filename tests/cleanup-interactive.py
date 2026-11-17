#!/usr/bin/env python3
"""Synthetic cleanup tests: no real tools or home files are ever removed."""
import os
import pty
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "scripts" / "setup" / "cleanup.sh"
SOURCE = ROOT / ".config" / "zsh" / "zshrc"
MANIFEST = ROOT / "scripts" / "setup" / "mise.toml"

with tempfile.TemporaryDirectory(prefix="dotfiles-cleanup-") as scratch:
    base = Path(scratch)
    home = base / "home"
    bin_dir = base / "bin"
    state = base / "installed"
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
case "$*" in
  "config get --file "*" tools.neovim")
    echo '0.12.6'
    ;;
  "config get --file "*" tools.zoxide")
    echo "0.10.0"
    ;;
  "config get --file "*" tools.zellij")
    echo "${MOCK_ZELLIJ_VERSION:-0.46.0}"
    ;;
  "uninstall --dry-run-code neovim@0.12.6")
    [[ -e "$MOCK_STATE/neovim" ]] && exit 1 || exit 0
    ;;
  "uninstall --dry-run-code zoxide@0.10.0")
    [[ -e "$MOCK_STATE/zoxide" ]] && exit 1 || exit 0
    ;;
  "uninstall --dry-run-code zellij@0.46.0")
    [[ -e "$MOCK_STATE/zellij" ]] && exit 1 || exit 0
    ;;
  "uninstall --yes neovim@0.12.6")
    rm -f -- "$MOCK_STATE/neovim"
    ;;
  "uninstall --yes zoxide@0.10.0")
    rm -f -- "$MOCK_STATE/zoxide"
    ;;
  "uninstall --yes zellij@0.46.0")
    rm -f -- "$MOCK_STATE/zellij"
    ;;
  "dot unapply --dry-run "*)
    ;;
  "dot unapply --yes "*)
    [[ -L "$HOME/.zshrc" ]] || exit 31
    rm -f -- "$HOME/.zshrc"
    ;;
  *)
    exit 23
    ;;
esac
""")
    mise.chmod(0o755)
    env = dict(os.environ)
    env.update({
        "HOME": str(home),
        "PATH": str(bin_dir) + os.pathsep + "/usr/bin:/bin",
        "MOCK_LOG": str(log),
        "MOCK_STATE": str(state),
    })
    target = home / ".zshrc"

    def run_quiet(args, input_text=None, overrides=None):
        return subprocess.run(
            ["bash", str(SCRIPT), *args], cwd=base, env={**env, **(overrides or {})},
            input=input_text,
            **({"stdin": subprocess.DEVNULL} if input_text is None else {}),
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
            check=False, timeout=12,
        )

    def run_tty(args, answers):
        master, slave = pty.openpty()
        try:
            proc = subprocess.Popen(
                ["bash", str(SCRIPT), *args], cwd=base, env=env,
                stdin=slave, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            )
            os.close(slave)
            slave = -1
            os.write(master, answers.encode())
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

    (state / "neovim").touch()
    (state / "zellij").touch()
    (state / "zoxide").touch()
    target.symlink_to(SOURCE)
    help_result = run_quiet(["--help"])
    assert help_result.returncode == 0 and "Usage:" in help_result.stdout
    assert run_quiet(["--unknown"]).returncode != 0
    assert run_quiet(["--apply", "--yes"]).returncode != 0

    # Default prints only previews and never changes a managed symlink or tools.
    preview = run_quiet([])
    assert preview.returncode == 0, preview.stdout
    assert "Preview only; no changes were made" in preview.stdout, preview.stdout
    assert target.is_symlink() and (state / "neovim").exists() and (state / "zellij").exists() and (state / "zoxide").exists()
    assert any("dot unapply --dry-run" in line for line in operations())
    assert any("uninstall --dry-run-code neovim@0.12.6" in line for line in operations())
    assert any("uninstall --dry-run-code zellij@0.46.0" in line for line in operations())
    assert any("uninstall --dry-run-code zoxide@0.10.0" in line for line in operations())
    assert not destructive(), operations()
    assert all(line.startswith(str(MANIFEST) + "|") for line in log.read_text().splitlines())

    # A piped yes cannot authorise removal.
    reset_log()
    piped = run_quiet(["--apply"], "yes\nyes\nyes\n")
    assert piped.returncode == 0, piped.stdout
    assert target.is_symlink() and (state / "neovim").exists() and (state / "zellij").exists() and (state / "zoxide").exists()
    assert not destructive(), operations()

    # Existing different symlinks and ordinary files are never touched.
    reset_log()
    target.unlink()
    unrelated = base / "personal-zsh"
    unrelated.write_text("my own configuration\n")
    target.symlink_to(unrelated)
    foreign = run_quiet(["--apply"], "yes\nyes\nyes\n")
    assert foreign.returncode == 0 and target.is_symlink() and target.resolve() == unrelated.resolve(), foreign.stdout
    assert not any("dot unapply" in line for line in operations()), operations()
    target.unlink()
    target.write_text("custom config\n")
    reset_log()
    real = run_quiet([])
    assert real.returncode == 0 and target.read_text() == "custom config\n"
    assert not any("dot unapply" in line for line in operations()), operations()
    target.unlink()

    # Per-component approval: decline zsh, accept Neovim, decline Zellij.
    reset_log()
    target.symlink_to(SOURCE)
    status, output = run_tty(["--apply"], "n\ny\nn\nn\n")
    assert status == 0, output
    assert target.is_symlink() and not (state / "neovim").exists()
    assert (state / "zellij").exists() and (state / "zoxide").exists(), output
    assert destructive() == ["-C / uninstall --yes neovim@0.12.6"], operations()

    # Subsequent run removes only the remaining approved items.
    reset_log()
    status, output = run_tty(["--apply"], "y\ny\ny\n")
    assert status == 0, output
    assert not target.exists() and not (state / "zellij").exists() and not (state / "zoxide").exists(), output
    assert destructive() == [
        f"-C / dot unapply --yes {target}",
        "-C / uninstall --yes zellij@0.46.0",
        "-C / uninstall --yes zoxide@0.10.0",
    ], operations()

    # Repeat is safe; no managed state or tools remain.
    reset_log()
    repeated = run_quiet(["--apply"])
    assert repeated.returncode == 0, repeated.stdout
    assert not destructive(), operations()

    # A changed/unpinned version is never guessed for uninstall.
    reset_log()
    bad_version = run_quiet([], overrides={"MOCK_ZELLIJ_VERSION": "latest"})
    assert bad_version.returncode != 0, bad_version.stdout
    assert "not an exact release" in bad_version.stdout
    assert not destructive(), operations()

    print("PASS: Cleanup preview, zoxide scope, isolated manifest, consent and reruns")
