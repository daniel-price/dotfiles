#!/usr/bin/env python3
"""Generate all configuration references for the documentation build."""

from pathlib import Path
import sys

from zsh import render as render_zsh
from zellij import render as render_zellij

ROOT = Path(__file__).resolve().parents[2]
OUTPUTS = {
    "zsh.md": render_zsh,
    "zellij.md": render_zellij,
}


def main() -> None:
    output_dir = ROOT / "docs/guides"
    for filename, renderer in OUTPUTS.items():
        generated = renderer()
        (output_dir / filename).write_text(generated)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError) as exc:
        sys.exit(f"Documentation generation failed: {exc}")
