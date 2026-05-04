#!/usr/bin/env python3
"""
Convert a NixOS options.json to a Markdown fragment suitable for {{#include}}
in mdbook.  Each option gets its own level-4 heading plus a two-column
metadata table, followed by its description and a source declaration line.

Usage: gen-options-md.py <options.json> <prefix> <output.md>
"""

import json
import sys


def render_value(val):
    """Collapse a NixOS literalExpression / literalMD / plain value to a string."""
    if val is None:
        return None
    if isinstance(val, dict):
        type = val.get("_type", "")
        if type in ("literalExpression", "literalMD"):
            return val.get("text", "")
        return json.dumps(val)
    if isinstance(val, bool):
        return "true" if val else "false"
    return str(val)


def escape_cell(s):
    """Escape pipe characters and collapse newlines so table cells stay intact."""
    return s.replace("|", "\\|").replace("\n", " ").strip()


def main():
    options_path, prefix, output_path = sys.argv[1], sys.argv[2], sys.argv[3]

    with open(options_path) as f:
        options = json.load(f)

    # Filter to requested prefix and drop internal module-system keys.
    items = sorted(
        [
            (k, v)
            for k, v in options.items()
            if (k == prefix or k.startswith(prefix + ".")) and not k.startswith("_")
        ],
        key=lambda x: x[0],
    )

    lines = []
    for name, opt in items:
        lines.append(f"#### `{name}`\n")

        type_str = opt.get("type", "—")
        default_val = render_value(opt.get("default"))
        example_val = render_value(opt.get("example"))

        lines.append("| | |")
        lines.append("|---|---|")
        lines.append(f"| **Type** | `{escape_cell(type_str)}` |")
        if default_val is not None:
            lines.append(f"| **Default** | `{escape_cell(default_val)}` |")
        if example_val is not None:
            lines.append(f"| **Example** | `{escape_cell(example_val)}` |")

        lines.append("")

        description = opt.get("description", "").strip()
        if description:
            lines.append(description)
            lines.append("")

        decls = opt.get("declarations", [])
        if decls:
            links = ", ".join(f"`{d}`" for d in decls)
            lines.append(f"*Declared in: {links}*\n")

        lines.append("---\n")

    with open(output_path, "w") as f:
        f.write("\n".join(lines) + "\n")


if __name__ == "__main__":
    main()
