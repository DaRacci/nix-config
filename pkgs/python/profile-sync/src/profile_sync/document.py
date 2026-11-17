"""Round-trip editing of a profile `config.yaml` at dot-path granularity.

The file is hand-maintained and Hermes writes it too, so comments, key order, quoting and
YAML 1.1 booleans survive an edit the reconciler did not author.
"""

from __future__ import annotations

import datetime
import io
from pathlib import Path
from typing import Any

from ruamel.yaml import YAML
from ruamel.yaml.comments import CommentedMap

from .policy import get_path

YAML_VERSION = (1, 1)
# Below this width ruamel re-wraps long plain scalars, rewriting lines the policy never
# mentioned.
YAML_WIDTH = 4096
# Upstream uses these for formatting.
MAPPING_INDENT = 2
SEQUENCE_INDENT = 4
SEQUENCE_OFFSET = 2


def new_yaml() -> YAML:
    yaml = YAML()
    yaml.version = YAML_VERSION
    yaml.preserve_quotes = True
    yaml.width = YAML_WIDTH
    yaml.default_flow_style = False
    yaml.indent(
        mapping=MAPPING_INDENT, sequence=SEQUENCE_INDENT, offset=SEQUENCE_OFFSET
    )
    return yaml


def values_equal(desired: Any, current: Any) -> bool:
    """Compare a JSON policy value with a YAML-loaded one.

    YAML 1.1 turns a date-shaped string into `datetime.date`, so a policy string of
    `2026-11-05` would otherwise read as a change on every run and never converge.
    """
    if desired == current:
        return True
    return isinstance(current, datetime.date) and str(current) == desired


class ConfigDocument:
    """One profile's config.yaml, edited in place and serialised on demand."""

    def __init__(self, path: Path) -> None:
        self.path = path
        self.yaml = new_yaml()
        self._original = path.read_text(encoding="utf-8") if path.exists() else ""
        data = self.yaml.load(self._original) if self._original.strip() else None
        self.data: Any = data if data is not None else CommentedMap()
        self._dirty = False

    def get(self, path: str) -> tuple[bool, Any]:
        return get_path(self.data, path)

    def set(self, path: str, value: Any) -> None:
        *parents, leaf = path.split(".")
        node = self.data
        for part in parents:
            child = node.get(part) if isinstance(node, dict) else None
            if not isinstance(child, dict):
                # A scalar where the policy wants a mapping. Replacing it is the only
                # way to satisfy the policy, and the whole file is backed up first.
                child = CommentedMap()
                node[part] = child
            node = child
        node[leaf] = value
        self._dirty = True

    def delete(self, path: str) -> bool:
        *parents, leaf = path.split(".")
        node = self.data
        for part in parents:
            if not isinstance(node, dict) or part not in node:
                return False
            node = node[part]
        if not isinstance(node, dict) or leaf not in node:
            return False
        del node[leaf]
        self._dirty = True
        return True

    def text(self) -> str:
        if not self._dirty:
            return self._original
        buffer = io.StringIO()
        self.yaml.dump(self.data, buffer)
        return buffer.getvalue()

    def changed(self) -> bool:
        return self.text() != self._original
