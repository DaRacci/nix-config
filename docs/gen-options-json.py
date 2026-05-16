#!/usr/bin/env python3
"""
Convert a NixOS options.json to a slim JSON array consumed by the
nix-options-widget client-side JavaScript.

Output format: [{ name, type, default, example, description, declarations, readOnly }]

Usage: gen-options-json.py <options.json> <prefix> <output.json>
"""
import json
import sys


def render_value(val):
    if val is None:
        return None
    if isinstance(val, dict):
        typ = val.get("_type", "")
        if typ in ("literalExpression", "literalMD"):
            return val.get("text", "")
        return json.dumps(val)
    if isinstance(val, bool):
        return "true" if val else "false"
    return str(val)


def main():
    options_path, prefix, output_path = sys.argv[1], sys.argv[2], sys.argv[3]

    with open(options_path) as f:
        options = json.load(f)

    result = []
    for name, opt in sorted(options.items()):
        if (name == prefix or name.startswith(prefix + ".")) and not name.startswith("_"):
            result.append(
                {
                    "name": name,
                    "type": opt.get("type", ""),
                    "default": render_value(opt.get("default")),
                    "example": render_value(opt.get("example")),
                    "description": opt.get("description", "").strip(),
                    "declarations": opt.get("declarations", []),
                    "readOnly": opt.get("readOnly", False),
                }
            )

    with open(output_path, "w") as f:
        json.dump(result, f, indent=2)
        f.write("\n")


if __name__ == "__main__":
    main()
