"""Add a mise environment without discarding existing local settings."""
import json
import os
from pathlib import Path
import re
import sys
import tempfile
import tomllib


def add_environment(path: Path, name: str) -> None:
    if path.is_symlink():
        raise ValueError("Refusing to replace a symlink")
    original = path.read_text() if path.exists() else ""
    parsed = tomllib.loads(original)
    env = parsed.get("env", [])
    if not isinstance(env, list) or not all(isinstance(item, str) for item in env):
        raise ValueError("Expected env to be a list of strings")
    if name in env:
        return
    line = "env = " + json.dumps([*env, name], ensure_ascii=False)
    if "env" in parsed:
        # Preserve other settings and comments; refuse unsupported multiline syntax.
        matches = list(re.finditer(r"(?m)^([ \t]*)env[ \t]*=[ \t]*\[[^\r\n]*?\][ \t]*(#[^\r\n]*)?$", original))
        if len(matches) != 1:
            raise ValueError("Edit the complex env declaration manually")
        match = matches[0]
        comment = " " + match.group(2) if match.group(2) else ""
        updated = original[:match.start()] + match.group(1) + line + comment + original[match.end():]
    else:
        updated = line + "\n" + original
    if tomllib.loads(updated) != {**parsed, "env": [*env, name]}:
        raise ValueError("Unexpected TOML change; edit manually")
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, delete=False) as handle:
        temporary = Path(handle.name)
        handle.write(updated)
    try:
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


if __name__ == "__main__":
    try:
        add_environment(Path(sys.argv[1]), sys.argv[2])
    except (OSError, ValueError) as error:
        sys.exit(str(error))
