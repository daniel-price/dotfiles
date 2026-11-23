#!/usr/bin/env python3
"""Portable aliases and prompt startup with and without optional dependency."""
import os
import shutil
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ZSHRC = ROOT / ".config/zsh/zshrc"
ALIASES = ROOT / ".config/zsh/aliases.zsh"
PROMPT = ROOT / ".config/zsh/p10k.zsh"

assert ZSHRC.is_file() and ALIASES.is_file() and PROMPT.is_file()
assert "POWERLEVEL9K_CONFIG_FILE" in PROMPT.read_text()
assert "alias zj='zellij'" in ALIASES.read_text()
assert 'mise activate zsh' in ZSHRC.read_text()
assert 'source "$_dotfiles_zsh_dir/aliases.zsh"' in ZSHRC.read_text()
assert "profiles.zsh" not in ZSHRC.read_text()
assert "MISE_GLOBAL_CONFIG_FILE" not in ZSHRC.read_text()

assert 'source "$_dotfiles_zsh_dir/p10k.zsh"' in ZSHRC.read_text()
assert "git clone" not in ZSHRC.read_text()

zsh = shutil.which("zsh")
if not zsh:
    print("SKIP: Zsh startup runtime tests (zsh is not installed)")
    raise SystemExit(0)

with tempfile.TemporaryDirectory(prefix="dotfiles-zsh-startup-") as temporary:
    home = Path(temporary)
    (home / ".zshrc").symlink_to(ZSHRC)
    env = dict(os.environ, HOME=str(home), PATH="/usr/bin:/bin",
               TERM_PROGRAM="", USER="testuser")
    env.pop("MISE_GLOBAL_CONFIG_FILE", None)

    def run(expr, interactive=False, overrides=None):
        return subprocess.run([zsh, "-f", "-ic" if interactive else "-c",
                               f'source "$HOME/.zshrc"; {expr}'],
                              env=dict(env, **(overrides or {})),
                              stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                              stderr=subprocess.STDOUT, text=True, timeout=15)

    # Native mise discovery needs no shell-level configuration override.
    native = run('print -r -- "MISE=${MISE_GLOBAL_CONFIG_FILE:-unset}"')
    assert native.returncode == 0 and "MISE=unset" in native.stdout, native.stdout
    custom = run('print -r -- "MISE=${MISE_GLOBAL_CONFIG_FILE:-unset}"',
                 overrides={"MISE_GLOBAL_CONFIG_FILE": "/tmp/custom-mise.toml"})
    assert custom.returncode == 0 and "MISE=/tmp/custom-mise.toml" in custom.stdout

    aliases = run("alias zj za zar g; print -r -- ZSH_READY")
    assert aliases.returncode == 0, aliases.stdout
    for snippet in ("zj=zellij", "za='zellij action'", "zar='zellij action rename-tab'",
                    "g=git", "ZSH_READY"):
        assert snippet in aliases.stdout, (snippet, aliases.stdout)

    # With no theme checkout, startup should not source a missing file or
    # try to clone/install anything; existing shell remains usable.
    absent = run("print -r -- ZSH_READY", interactive=True)
    assert absent.returncode == 0 and "ZSH_READY" in absent.stdout, absent.stdout
    assert "no such file" not in absent.stdout.lower(), absent.stdout

    # A fake theme at the declared location witnesses the source order.
    theme_dir = home / ".local/share/dotfiles/powerlevel10k"
    theme_dir.mkdir(parents=True)
    (theme_dir / "powerlevel10k.zsh-theme").write_text(
        "typeset -g _DOTFILES_P10K_THEME_LOADED=yes\n"
    )
    loaded = run(
        'print -r -- "THEME=$_DOTFILES_P10K_THEME_LOADED" '
        '"CONFIG=$POWERLEVEL9K_CONFIG_FILE"',
        interactive=True,
    )
    assert loaded.returncode == 0 and "THEME=yes" in loaded.stdout, loaded.stdout
    assert "p10k.zsh" in loaded.stdout, loaded.stdout

    vscode = run(
        'print -r -- "THEME=${_DOTFILES_P10K_THEME_LOADED:-off}"',
        interactive=True, overrides={"TERM_PROGRAM": "vscode"},
    )
    assert vscode.returncode == 0 and "THEME=off" in vscode.stdout, vscode.stdout

    # An installed plugin is sourced in interactive shells, not in scripts.
    plugin_dir = home / ".local/share/dotfiles/zsh-autosuggestions"
    plugin_dir.mkdir(parents=True)
    (plugin_dir / "zsh-autosuggestions.zsh").write_text(
        "typeset -g _DOTFILES_AUTOSUGGESTIONS_LOADED=yes\n"
        "_zsh_autosuggest_start() { :; }\n"
    )
    plugin = run(
        'print -r -- "PLUGIN=${_DOTFILES_AUTOSUGGESTIONS_LOADED:-off}" '
        '"STRATEGIES=${(j:,:)ZSH_AUTOSUGGEST_STRATEGY}"',
        interactive=True,
    )
    assert plugin.returncode == 0, plugin.stdout
    assert "PLUGIN=yes" in plugin.stdout, plugin.stdout
    assert "STRATEGIES=dotfiles_bookmarks,history" in plugin.stdout, plugin.stdout
    no_plugin = run('print -r -- "PLUGIN=${_DOTFILES_AUTOSUGGESTIONS_LOADED:-off}"')
    assert no_plugin.returncode == 0 and "PLUGIN=off" in no_plugin.stdout, no_plugin.stdout

    print("PASS: Native mise Zsh startup, aliases, prompt and autosuggestions")
