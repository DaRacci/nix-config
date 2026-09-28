#!/usr/bin/env python3

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

INCLUDE_PATTERN = re.compile(r"^\s*\{\{#include\s+([^\s}]+)")
DEFAULT_SRC_ROOT = Path("src")


def find_include_errors(src_root: Path) -> list[str]:
    if not src_root.is_dir():
        raise FileNotFoundError(f"mdBook source root not found: {src_root}")

    errors: list[str] = []
    for markdown_path in sorted(src_root.rglob("*.md")):
        content = markdown_path.read_text(encoding="utf-8")
        for line_number, line in enumerate(content.splitlines(), start=1):
            match = INCLUDE_PATTERN.match(line)
            if match is None:
                continue

            include_target = match.group(1)
            resolved_path = (markdown_path.parent / include_target).resolve()
            if resolved_path.is_file():
                continue

            relative_markdown_path = markdown_path.relative_to(src_root)
            try:
                relative_target_path = resolved_path.relative_to(src_root.parent)
            except ValueError:
                relative_target_path = resolved_path
            message = (
                f"{relative_markdown_path}:{line_number}: "
                f"include target not found: {include_target} -> {relative_target_path}"
            )
            errors.append(message)

    return errors


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate mdBook {{#include}} targets")
    parser.add_argument(
        "--src-root",
        type=Path,
        default=DEFAULT_SRC_ROOT,
        help="Path to the mdBook src directory (default: %(default)s)",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    argv = list(sys.argv[1:] if argv is None else argv)
    if len(argv) == 1 and argv[0] == "supports":
        return 0

    args = parse_args(argv)

    try:
        errors = find_include_errors(args.src_root.resolve())
    except FileNotFoundError as exc:
        print(exc, file=sys.stderr)
        return 1

    if errors:
        print("mdBook include validation failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
