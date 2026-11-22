#!/usr/bin/env python3
"""Preview and safely compose explicitly approved, locally cloned machine profiles.

This deliberately accepts only exact mise tool pins and static file mappings.
No config is sourced, packages installed or Git remotes contacted here.
"""
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import tomllib

MANAGED = "# Managed by dotfiles profile setup. Re-run the profile command to change.\n"
VALID_NAME = re.compile(r"[a-z][a-z0-9-]*\Z")
VALID_TOOL = re.compile(r"[a-z][a-z0-9_-]*\Z")
VALID_PIN = re.compile(r"[0-9]+(?:\.[0-9]+)+\Z")


def refuse(reason):
    raise ValueError(reason)


def safe_file(path):
    if path.is_symlink() or not path.is_file():
        refuse(f"Expected regular file, not a symlink: {path}")


def safe_directory(path):
    if path.is_symlink() or not path.is_dir():
        refuse(f"Expected regular directory, not a symlink: {path}")


def parents_safe(path, home):
    """No target may traverse a pre-existing symlink or non-directory."""
    parent = path.parent
    while parent != home:
        if parent.exists() or parent.is_symlink():
            safe_directory(parent)
        parent = parent.parent
    safe_directory(home)


def tools_file(path, profile=False):
    safe_file(path)
    data = tomllib.loads(path.read_text(encoding="utf-8"))
    if profile and set(data) != {"tools"}:
        refuse(f"{path}: profile mise.toml must contain only [tools]")
    entries = data.get("tools")
    if not isinstance(entries, dict):
        refuse(f"{path}: missing [tools] table")
    for key, value in entries.items():
        if not VALID_TOOL.fullmatch(key) or not isinstance(value, str) or not VALID_PIN.fullmatch(value):
            refuse(f"{path}: tool pins must be exact numeric versions")
    return entries


def checked_repo(repo):
    safe_directory(repo)
    safe_directory(repo / ".git")
    result = subprocess.run(
        ["git", "-C", str(repo), "rev-parse", "--show-toplevel"],
        capture_output=True, text=True, check=True,
    )
    if Path(result.stdout.strip()).resolve() != repo.resolve():
        refuse(f"Not an independent Git checkout: {repo}")
    result = subprocess.run(
        ["git", "-C", str(repo), "status", "--porcelain", "--untracked-files=all"],
        capture_output=True, text=True, check=True,
    )
    if result.stdout.strip():
        refuse(f"Profile repository has uncommitted changes: {repo}")
    for dirname in ("bin", "zsh", "config"):
        candidate = repo / dirname
        if candidate.exists() or candidate.is_symlink():
            safe_directory(candidate)


def contained_files(directory):
    """Reject symlinked descendants, including directories."""
    if not directory.exists() and not directory.is_symlink():
        return []
    safe_directory(directory)
    files = []
    for root, dirs, names in os.walk(directory, followlinks=False):
        for name in dirs:
            safe_directory(Path(root) / name)
        for name in names:
            candidate = Path(root) / name
            safe_file(candidate)
            files.append(candidate)
    return sorted(files)


def read_active(registry):
    if not registry.exists() and not registry.is_symlink():
        return []
    safe_file(registry)
    content = registry.read_text(encoding="utf-8")
    if not content.startswith(MANAGED):
        refuse(f"Unmanaged existing active profiles file: {registry}")
    names = content[len(MANAGED):].splitlines()
    if any(not VALID_NAME.fullmatch(name) for name in names) or len(set(names)) != len(names):
        refuse("Invalid or duplicate active profile name")
    return names


def check_managed(path):
    if not path.exists() and not path.is_symlink():
        return
    safe_file(path)
    if not path.read_text(encoding="utf-8").startswith(MANAGED):
        refuse(f"Refusing to overwrite unmanaged file: {path}")


def render_tools(items):
    return (
        MANAGED + "[tools]\n"
        + "".join(f"{tool} = {json.dumps(version)}\n" for tool, version in sorted(items.items()))
        + "\n[settings]\nauto_install = false\n"
    )


def build(root, home, checkout_root, name):
    safe_directory(home)
    safe_directory(root)
    if not VALID_NAME.fullmatch(name):
        refuse("Profile name must be lowercase letters, digits or hyphens, beginning with a letter")
    if checkout_root.is_symlink():
        refuse(f"Profile parent directory cannot be a symlink: {checkout_root}")
    safe_directory(checkout_root)
    registry = home / ".config/dotfiles/active-profiles"
    manifest = home / ".config/mise/dotfiles-profiles.toml"
    for target in (registry, manifest):
        parents_safe(target, home)
        check_managed(target)

    active = read_active(registry)
    names = active if name in active else [*active, name]
    public_tools = tools_file(root / "scripts/setup/mise.toml")
    merged = dict(public_tools)
    mappings = {}
    bins = set()
    functions = set()
    profile_sources = {}
    for selected in names:
        repo = checkout_root / selected
        checked_repo(repo)
        profile_sources[selected] = repo
        for tool, version in tools_file(repo / "mise.toml", profile=True).items():
            if tool in merged and merged[tool] != version:
                refuse(f"Conflicting tool pin for {tool}: {merged[tool]} vs {version}")
            merged[tool] = version
        for command in contained_files(repo / "bin"):
            if command.parent != repo / "bin":
                refuse(f"Nested bin command is unsupported: {command}")
            if command.name in bins or (root / "bin" / command.name).exists():
                refuse(f"Conflicting executable name: {command.name}")
            if not os.access(command, os.X_OK):
                refuse(f"Profile command is not executable: {command}")
            bins.add(command.name)
        alias_file = repo / "zsh/aliases.zsh"
        if alias_file.exists() or alias_file.is_symlink():
            safe_file(alias_file)
        for function in contained_files(repo / "zsh/functions"):
            if function.parent != repo / "zsh/functions":
                refuse(f"Nested Zsh function is unsupported: {function}")
            if function.name in functions or (root / ".config/zsh/functions" / function.name).exists():
                refuse(f"Conflicting Zsh function: {function.name}")
            functions.add(function.name)
        for source in contained_files(repo / "config"):
            relative = source.relative_to(repo / "config")
            if relative.parts[0] in ("mise", "dotfiles"):
                refuse(f"Reserved private configuration target: {relative}")
            target = home / ".config" / relative
            parents_safe(target, home)
            if target in mappings:
                refuse(f"Two profiles want the same app config target: {relative}")
            mappings[target] = source

    for target, source in mappings.items():
        if target.is_symlink():
            if not target.resolve(strict=False) == source.resolve():
                refuse(f"Foreign symlink at config target: {target}")
        elif target.exists():
            refuse(f"Existing non-profile file at config target: {target}")

    return names, merged, mappings, registry, manifest, profile_sources, public_tools


def atomic_write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and path.read_text(encoding="utf-8") == text:
        return
    fd, temporary = tempfile.mkstemp(prefix=".dotfiles-profile-", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as dest:
            dest.write(text)
        os.chmod(temporary, 0o600)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def main():
    if len(sys.argv) != 6:
        sys.exit("Usage: profile-config.py plan|apply|tools ROOT HOME PROFILE_ROOT NAME")
    action, root_arg, home_arg, checkout_arg, name = sys.argv[1:]
    if action not in ("plan", "apply", "tools"):
        refuse(f"Unknown action: {action}")
    root, home, checkout_root = [Path(p).absolute() for p in (root_arg, home_arg, checkout_arg)]
    if home == Path("/") or checkout_root == home or checkout_root == root:
        refuse("Unsafe profile location")
    names, tools, mappings, registry, manifest, profiles, public = build(
        root, home, checkout_root, name
    )
    if action == "tools":
        requested = tools_file(profiles[name] / "mise.toml", profile=True)
        for tool, version in sorted(requested.items()):
            if tool not in public:
                print(f"{tool}@{version}")
        return
    if action == "plan":
        print(f"Selected profiles (in order): {', '.join(names)}")
        print(f"Effective mise pins: {', '.join(f'{k}@{v}' for k, v in sorted(tools.items()))}")
        print(f"Shell will load bin/, zsh/aliases.zsh and zsh/functions/ from each selected repository.")
        for target, source in mappings.items():
            state = "already linked" if target.is_symlink() else "new symlink"
            print(f"{state}: {target} -> {source}")
        print(f"Managed registry: {registry}")
        print(f"Managed mise manifest: {manifest}")
        print("No changes made. Profile code will be loaded only in subsequent shell sessions.")
        return

    # All conflicts are checked before the first write. Never overwrite foreign files.
    created = []
    try:
        for target, source in mappings.items():
            if target.is_symlink():
                continue
            target.parent.mkdir(parents=True, exist_ok=True)
            target.symlink_to(source)
            created.append(target)
        atomic_write(manifest, render_tools(tools))
        atomic_write(registry, MANAGED + "".join(f"{profile}\n" for profile in names))
    except Exception:
        for target in reversed(created):
            target.unlink()
        raise
    print(f"Applied: {', '.join(names)}; open a new Zsh session to load aliases and commands.")
    print(f"Managed mise config: {manifest}")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, subprocess.CalledProcessError, tomllib.TOMLDecodeError) as error:
        sys.exit(f"Profile setup refused: {error}")
