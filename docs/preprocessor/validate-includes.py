#!/usr/bin/env python3

import re
import sys
from pathlib import Path

include_pattern = re.compile(r"^\s*\{\{#include\s+([^\s}]+)")


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "supports":
        sys.exit(0)

    src_root = Path("src").resolve()
    errors = []

    for markdown_path in sorted(src_root.rglob("*.md")):
        content = markdown_path.read_text(encoding="utf-8")
        for line_number, line in enumerate(content.splitlines(), start=1):
            match = include_pattern.match(line)
            if match is None:
                continue

            include_target = match.group(1)
            resolved_path = (markdown_path.parent / include_target).resolve()

            if not resolved_path.is_file():
                pd_path = markdown_path.relative_to(src_root)
                try:
                    res_path = resolved_path.relative_to(src_root.parent)
                except ValueError:
                    res_path = str(resolved_path)
                errors.append(
                    f"{pd_path}:{line_number}: include target not found: {include_target} -> {res_path}"
                )

    if errors:
        print("mdBook include validation failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
