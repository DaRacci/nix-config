#!/usr/bin/env python3
"""
Generate Markdown fragments from NixOS options JSON for mdBook includes.
Each option gets a level-4 heading, metadata table, and description block.

Usage: gen-options-md.py <options.json> <prefix> <output.md>
"""

from __future__ import annotations

import argparse
import json
import sys
from collections.abc import Iterable, Mapping
from pathlib import Path

# Directories that group modules by topic rather than contributing to the NixOS option path.
# When derived prefix starts with one of these, also try prefix without it (for example, "ai.mnemosyne" -> "mnemosyne").
NAMESPACE_FOLDERS = {"ai"}

OptionMapping = Mapping[str, object]
OptionItem = tuple[str, OptionMapping]


def render_value(value: object) -> str | None:
    """Collapse NixOS option values into display strings."""
    if value is None:
        return None
    if isinstance(value, dict):
        value_type = value.get("_type", "")
        if value_type in ("literalExpression", "literalMD"):
            text = value.get("text", "")
            return text if isinstance(text, str) else str(text)
        return json.dumps(value)
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (list, tuple)):
        return json.dumps(value)
    return str(value)


def escape_cell(value: str) -> str:
    """Escape pipe characters and collapse newlines for Markdown tables."""
    return value.replace("|", "\\|").replace("\n", " ").strip()


def candidate_prefixes(prefix: str, output_path: str | Path) -> list[str]:
    """Return likely option prefixes for user input and output filename."""
    candidates: list[str] = []

    def add(value: str) -> None:
        if value and value not in candidates:
            candidates.append(value)

    def add_variants(value: str) -> None:
        add(value)
        add(value.replace("-", "."))

        parts = value.split("-")
        if len(parts) < 2:
            return

        def expand(segments: list[str]) -> list[str]:
            if len(segments) == 1:
                return [segments[0]]

            results: list[str] = []
            head = segments[0]
            for tail in expand(segments[1:]):
                results.append(head + "-" + tail)
                results.append(head + "." + tail)
                results.append(head + tail[0].upper() + tail[1:])
            return results

        for variant in expand(parts):
            add(variant)

    add_variants(prefix)

    first_segment = prefix.split(".", 1)[0]
    if first_segment in NAMESPACE_FOLDERS and prefix != first_segment:
        add_variants(prefix.removeprefix(first_segment + "."))

    stem = Path(output_path).stem.removesuffix("-options")
    add_variants(stem)

    return candidates


def collect_matching_options(
    options: Mapping[str, object], prefixes: list[str]
) -> list[OptionItem]:
    """Filter options to keys that match requested prefixes."""
    items: list[OptionItem] = []
    for name, option in sorted(options.items()):
        if name.startswith("_"):
            continue
        if not any(
            name == prefix or name.startswith(prefix + ".") for prefix in prefixes
        ):
            continue
        if not isinstance(option, Mapping):
            continue
        items.append((name, option))
    return items


def render_options_markdown(items: Iterable[OptionItem]) -> str:
    """Render matching options to Markdown."""
    lines: list[str] = []

    for name, option in items:
        lines.append(f"#### `{name}`\n")

        type_text = render_value(option.get("type")) or "—"
        default_value = render_value(option.get("default"))
        example_value = render_value(option.get("example"))

        lines.append("| | |")
        lines.append("|---|---|")
        lines.append(f"| **Type** | `{escape_cell(type_text)}` |")
        if default_value is not None:
            lines.append(f"| **Default** | `{escape_cell(default_value)}` |")
        if example_value is not None:
            lines.append(f"| **Example** | `{escape_cell(example_value)}` |")

        lines.append("")

        description = (render_value(option.get("description")) or "").strip()
        if description:
            lines.append(description)
            lines.append("")

        lines.append("---\n")

    if not lines:
        return ""

    return "\n".join(lines) + "\n"


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate Markdown fragments from NixOS options JSON"
    )
    parser.add_argument("options_json", type=Path, help="Path to options.json")
    parser.add_argument("prefix", help="Option prefix to include")
    parser.add_argument("output_md", type=Path, help="Path to output Markdown file")
    return parser.parse_args(argv)


def generate_markdown(
    options_json: Path, prefix: str, output_md: Path
) -> tuple[list[str], str]:
    """Generate Markdown for matching options and write it when non-empty."""
    parsed = json.loads(options_json.read_text(encoding="utf-8"))
    if not isinstance(parsed, Mapping):
        raise TypeError(f"expected top-level JSON object in {options_json}")

    prefixes = candidate_prefixes(prefix, output_md)
    items = collect_matching_options(parsed, prefixes)
    markdown = render_options_markdown(items)

    output_md.parent.mkdir(parents=True, exist_ok=True)
    output_md.write_text(markdown, encoding="utf-8")

    return prefixes, markdown


def main(argv: list[str] | None = None) -> int:
    argv = list(sys.argv[1:] if argv is None else argv)
    args = parse_args(argv)
    prefixes, markdown = generate_markdown(
        args.options_json, args.prefix, args.output_md
    )

    if not markdown:
        print(
            f"Warning: no options found for prefixes {prefixes} in {args.options_json}",
            file=sys.stderr,
        )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
