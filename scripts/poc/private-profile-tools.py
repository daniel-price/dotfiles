#!/usr/bin/env python3
"""Compose pinned, synthetic mise tool inventories without executing config."""

import json
from pathlib import Path
import re
import sys

try:
    import tomllib
except ImportError:
    sys.exit("Python 3.11+ is required for the private-profile POC")


def tools_from(path: Path) -> dict[str, str]:
    data = tomllib.loads(path.read_text(encoding="utf-8"))
    if set(data) != {"tools"} or not isinstance(data["tools"], dict):
        raise ValueError(f"{path}: POC accepts only a [tools] table")
    result = data["tools"]
    for name, version in result.items():
        if not re.fullmatch(r"[a-z][a-z0-9_-]*", name):
            raise ValueError(f"{path}: unsafe tool name")
        if not isinstance(version, str) or not re.fullmatch(r"\d+\.\d+\.\d+", version):
            raise ValueError(f"{path}: tool versions must be exact numeric pins")
    return result


def main() -> None:
    if len(sys.argv) != 4:
        sys.exit("Usage: private-profile-tools.py PUBLIC_TOML PROFILE_TOML OUTPUT_TOML")
    public, profile, output = map(Path, sys.argv[1:])
    base = tools_from(public)
    overlay = tools_from(profile)
    for name, version in overlay.items():
        if name in base and base[name] != version:
            raise ValueError(f"Conflicting tool pin for {name}; refusing silent override")
        base[name] = version
    if output.exists() or output.is_symlink():
        raise ValueError("Refusing to overwrite an existing tools manifest")
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(
        "# Synthetic effective tools; no software is installed.\n[tools]\n"
        + "".join(f"{name} = {json.dumps(value)}\n" for name, value in sorted(base.items()))
        + "\n[settings]\nauto_install = false\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, tomllib.TOMLDecodeError) as error:
        sys.exit(f"Profile composition refused: {error}")
