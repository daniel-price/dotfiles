#!/usr/bin/env python3
"""Render argc --argc-export JSON as Markdown for the docs build.

Usage: argc --argc-export ./bin/my-tool | python3 export_to_markdown.py
This is intentionally a small presenter, not a parser for argc annotations.
"""
import json
import sys

TICK = chr(96)


def clean(value):
    """Escape Markdown table separators and multiline descriptions."""
    return str(value).replace("|", "\\|").replace("\n", "<br>")


def default(value):
    if value is None:
        return "—"
    if isinstance(value, dict):
        kind = value.get("type")
        if kind == "Value":
            return clean(value.get("value", ""))
        if kind == "Fn":
            return "dynamic (" + clean(value.get("value", "")) + ")"
    return clean(value)


def choices(value):
    if value is None:
        return "—"
    if isinstance(value, dict):
        kind = value.get("type")
        data = value.get("data", [])
        if kind == "Values":
            return ", ".join(clean(item) for item in data) or "—"
        if kind == "Fn":
            return "dynamic (" + clean(data[0] if data else "") + ")"
    return clean(value)


def table(lines, columns, rows):
    if not rows:
        return
    lines.extend(["| " + " | ".join(columns) + " |",
                  "| " + " | ".join("---" for _ in columns) + " |"])
    for row in rows:
        lines.append("| " + " | ".join(str(value) for value in row) + " |")
    lines.append("")


def render(command, prefix="", level=1):
    name = command["name"]
    full_name = (prefix + " " + name).strip()
    lines = ["#" * min(level, 6) + " " + TICK + full_name + TICK, ""]
    description = command.get("describe") or ""
    if description:
        lines.extend([description.strip(), ""])

    opts = []
    for option in command.get("flag_options", []):
        names = ", ".join(option.get("names", []))
        if not option.get("flag") and option.get("notations"):
            names += " " + " ".join("<" + val + ">" for val in option["notations"])
        opts.append((TICK + clean(names) + TICK, clean(option.get("describe", "")),
                     "yes" if option.get("required") else "no",
                     default(option.get("default")), choices(option.get("choice"))))
    if opts:
        lines.extend(["#" * min(level + 1, 6) + " Options", ""])
        table(lines, ["Flag / option", "Description", "Required", "Default", "Choices"], opts)

    args = []
    for arg in command.get("positionals", []):
        notation = arg.get("notation") or arg.get("id", "")
        if arg.get("multiple"):
            notation += "..."
        args.append((TICK + clean(notation) + TICK, clean(arg.get("describe", "")),
                     "yes" if arg.get("required") else "no",
                     default(arg.get("default")), choices(arg.get("choice"))))
    if args:
        lines.extend(["#" * min(level + 1, 6) + " Arguments", ""])
        table(lines, ["Argument", "Description", "Required", "Default", "Choices"], args)

    subcommands = command.get("subcommands", [])
    if subcommands:
        lines.extend(["#" * min(level + 1, 6) + " Subcommands", ""])
        table(lines, ["Command", "Description"], [
            (TICK + clean(sub["name"]) + TICK, clean(sub.get("describe", "")))
            for sub in subcommands
        ])
        for sub in subcommands:
            lines.extend(render(sub, full_name, level + 1))

    return lines


def main():
    try:
        payload = json.load(sys.stdin)
        if not isinstance(payload, dict) or not isinstance(payload.get("name"), str):
            raise ValueError("argc export must be a command object with a name")
        print("\n".join(render(payload)).rstrip())
    except (ValueError, TypeError, KeyError) as exc:
        print("Cannot render argc export: " + str(exc), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
