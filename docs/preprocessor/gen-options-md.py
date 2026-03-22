#!/usr/bin/env python3
"""
Convert a NixOS options.json to a Markdown fragment suitable for {{#include}}
in mdbook.  Each option gets its own level-4 heading plus a two-column
metadata table, followed by its description and a source declaration line.

Usage: gen-options-md.py <options.json> <prefix> <output.md>
"""

import json
import sys
from pathlib import Path


def render_value(val):
    """Collapse a NixOS literalExpression / literalMD / plain value to a string."""
    if val is None:
        return None
    if isinstance(val, dict):
        val_type = val.get("_type", "")
        if val_type in ("literalExpression", "literalMD"):
            return val.get("text", "")
        return json.dumps(val)
    if isinstance(val, bool):
        return "true" if val else "false"
    if isinstance(val, (list, tuple)):
        return json.dumps(val)
    return str(val)


def escape_cell(s):
    """Escape pipe characters and collapse newlines so table cells stay intact."""
    return s.replace("|", "\\|").replace("\n", " ").strip()


def candidate_prefixes(prefix, output_path):
    """Return likely option prefixes for user input and output filename."""
    candidates = []

    def add(value):
        if value and value not in candidates:
            candidates.append(value)

    def add_variants(value):
        add(value)
        add(value.replace("-", "."))

        parts = value.split("-")
        for i in range(1, len(parts)):
            add(".".join(parts[:i]) + "-" + "-".join(parts[i:]))

    add_variants(prefix)

    stem = Path(output_path).stem
    if stem.endswith("-options"):
        stem = stem[: -len("-options")]
    add_variants(stem)

    return candidates


def main():
    options_path, prefix, output_path = sys.argv[1], sys.argv[2], sys.argv[3]

    with open(options_path, encoding="utf-8") as f:
        options = json.load(f)

    prefixes = candidate_prefixes(prefix, output_path)

    # Filter to requested prefix and drop internal module-system keys.
    items = sorted(
        [
            (k, v)
            for k, v in options.items()
            if not k.startswith("_")
            and any(k == p or k.startswith(p + ".") for p in prefixes)
        ],
        key=lambda x: x[0],
    )

    lines = []
    for name, opt in items:
        lines.append(f"#### `{name}`\n")

        type_str = render_value(opt.get("type")) or "—"
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

        description = (render_value(opt.get("description")) or "").strip()
        if description:
            lines.append(description)
            lines.append("")

        # decls = opt.get("declarations", [])
        # if decls:
        #     links = ", ".join(f"`{d}`" for d in decls)
        #     lines.append(f"*Declared in: {links}*\n")

        lines.append("---\n")

    with open(output_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")


if __name__ == "__main__":
    main()
