"""Line-oriented editing of a profile `.env`.

The file is a shell-style key/value list with comments, blank separators and, in
practice, duplicate keys. Rewriting it through a dict would drop the comments and
reorder everything, so the reconciler edits lines and leaves every line it did not
have to touch byte-identical.
"""

from __future__ import annotations

import re
from pathlib import Path

_LINE = re.compile(r"^(?P<key>[A-Za-z_][A-Za-z0-9_]*)=(?P<value>.*)$")


def _unquote(value: str) -> str:
    if len(value) >= 2 and value[0] == value[-1] and value[0] in {"'", '"'}:
        return value[1:-1]
    return value


class EnvFile:
    """A `.env` file kept as raw lines."""

    def __init__(self, path: Path) -> None:
        self.path = path
        self._original = path.read_text(encoding="utf-8") if path.exists() else ""
        self._lines: list[str] = self._original.splitlines(keepends=True)

    def entries(self) -> dict[str, str]:
        """Last occurrence wins, matching how the file is read line by line."""
        found: dict[str, str] = {}
        for line in self._lines:
            match = _LINE.match(line.rstrip("\n"))
            if match:
                found[match.group("key")] = _unquote(match.group("value"))
        return found

    def get(self, key: str) -> str | None:
        return self.entries().get(key)

    def keys(self) -> list[str]:
        return list(self.entries())

    def set(self, key: str, value: str) -> None:
        """Write one key, collapsing any duplicate definitions of it.

        Only the key being written is normalised. Leaving a stale duplicate behind
        would make the value depend on the reader's precedence rule, and rewriting
        every other line would break the byte-identical guarantee for the rest.
        """
        if "\n" in value:
            raise ValueError(f"{key}: a .env value cannot contain a newline")
        replacement = f"{key}={value}\n"
        kept: list[str] = []
        seen = False
        for line in self._lines:
            match = _LINE.match(line.rstrip("\n"))
            if match and match.group("key") == key:
                if seen:
                    continue
                kept.append(replacement)
                seen = True
            else:
                kept.append(line)
        if not seen:
            if kept and not kept[-1].endswith("\n"):
                kept[-1] = f"{kept[-1]}\n"
            kept.append(replacement)
        self._lines = kept

    def delete(self, key: str) -> bool:
        kept = [line for line in self._lines if self._key_of(line) != key]
        if len(kept) == len(self._lines):
            return False
        self._lines = kept
        return True

    @staticmethod
    def _key_of(line: str) -> str | None:
        match = _LINE.match(line.rstrip("\n"))
        return match.group("key") if match else None

    def text(self) -> str:
        return "".join(self._lines)

    def changed(self) -> bool:
        return self.text() != self._original
