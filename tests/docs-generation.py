#!/usr/bin/env python3
"""Regression checks for references generated directly from configuration."""

from pathlib import Path
import sys
import tempfile

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts/docs"))
import zsh  # noqa: E402
import zellij  # noqa: E402
import tools  # noqa: E402
import cli  # noqa: E402
import argc_docs  # noqa: E402

zsh_page = zsh.render()
assert "# Zsh" in zsh_page
assert "| `zj` | `zellij` |" in zsh_page.replace("\\", "")
assert "interactivecomments" in zsh_page

zellij_page = zellij.render()
assert "# Zellij" in zellij_page
assert "| `locked` | `Ctrl a` | Switch to normal mode |" in zellij_page
assert "| `move` | `a` | Copy the active pane scrollback. |" in zellij_page
assert "| `move` | `l` | Copy the most recent shell command" in zellij_page
assert "| `move` | `p` | Open the interactive command picker" in zellij_page
assert "| `locked` | `Ctrl h` | Vim/Zellij navigator (left) |" in zellij_page
assert "| `default_mode` | `locked` |" in zellij_page
assert "pbcopy" in zellij_page and "fzf" in zellij_page
assert "migrated from" not in zellij_page.lower()

# Changes to KDL update the generated table without editing Markdown.
with tempfile.TemporaryDirectory() as temporary:
    file = Path(temporary) / "config.kdl"
    original = zellij.SOURCE.read_text()
    file.write_text(original.replace('bind "Ctrl a" {', 'bind "Ctrl b" {', 1))
    changed = zellij.render(file)
    assert "| `normal` | `Ctrl b` | Switch to locked mode |" in changed
    assert changed != zellij_page

    # Unmatched annotations fail rather than silently publishing stale docs.
    file.write_text(original + "\n// doc: binding normal:absent | No such binding.\n")
    try:
        zellij.render(file)
    except ValueError as error:
        assert "Annotations without matching" in str(error)
    else:
        raise AssertionError("Orphaned documentation annotation was accepted")

    file.write_text(original + "\n}\n")
    try:
        zellij.render(file)
    except ValueError as error:
        assert "Unmatched closing brace" in str(error)
    else:
        raise AssertionError("Unbalanced KDL was accepted")

tool_page = tools.render()
assert "| `neovim` | `0.12.6` |" in tool_page
assert "| `lefthook` | `2.2.2` |" in tool_page
assert "| `apt:zsh` | `linux` |" in tool_page
with tempfile.TemporaryDirectory() as temporary:
    machine = Path(temporary) / "machine.toml"
    development = Path(temporary) / "development.toml"
    machine.write_text((ROOT / "scripts/setup/base-tools.toml").read_text().replace('neovim = "0.12.6"', 'neovim = "99.1.0"'))
    development.write_text((ROOT / "mise.toml").read_text())
    changed = tools.render(machine, development)
    assert "| `neovim` | `99.1.0` |" in changed
    assert changed != tool_page

cli_page = cli.render()
assert "## Update and bootstrap" in cli_page
assert "Usage: ,bootstrap" in cli_page
assert "## OpenCode sandbox" in cli_page
assert "ANTHROPIC_API_KEY" in cli_page
assert "## Cleanup" in cli_page
assert "No secrets" not in cli_page
with tempfile.TemporaryDirectory() as temporary:
    root = Path(temporary)
    fixture = root / "demo.sh"
    fixture.write_text("""#!/usr/bin/env bash
if [[ "$1" == --help ]]; then printf 'Usage: demo.sh [--help]\n'; exit 0; fi
exit 1
""")
    assert cli.help_text(root, "demo.sh").startswith("Usage: demo.sh")
    fixture.write_text("""#!/usr/bin/env bash
if [[ "$1" == --help ]]; then touch "$HOME/mutated"; printf 'Usage: demo.sh\n'; fi
""")
    try:
        cli.help_text(root, "demo.sh")
    except ValueError as error:
        assert "temporary HOME" in str(error)
    else:
        raise AssertionError("Side-effecting help command was accepted")


# Structured argc exports are the only source for its Markdown reference.
sample = {
    "name": ",sample",
    "describe": "Example command",
    "flag_options": [{
        "short_name": "-n",
        "long_name": "--number",
        "notations": ["COUNT"],
        "describe": "Choose a count",
        "required": True,
        "flag": False,
        "default": {"type": "Value", "value": "2"},
        "choice": {"type": "Values", "data": ["1", "2"]},
    }],
    "positionals": [{"notation": "INPUT", "describe": "Some text", "required": True}],
    "subcommands": [{"name": "child", "describe": "Nested command"}],
}
rendered = argc_docs.render_export(sample)
assert "# `,sample`" in rendered
assert "`-n, --number <COUNT>`" in rendered
assert "| yes | 2 | 1, 2 |" in rendered
assert "`INPUT`" in rendered
assert "## Subcommands" in rendered
assert "## `,sample child`" in rendered
try:
    argc_docs.render_export({"not_a_command": True})
except ValueError as error:
    assert "command object" in str(error)
else:
    raise AssertionError("Invalid argc export accepted")

print("PASS: Generated Zsh/Zellij/tool/CLI references track configuration and reject invalid sources")
