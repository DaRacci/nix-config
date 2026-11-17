"""The outcome vocabulary every layer reports through."""

from __future__ import annotations

from enum import StrEnum


class Status(StrEnum):
    """One outcome line in the run report."""

    OK = "OK"
    NEW = "NEW"
    RELINK = "RELINK"
    ALIAS = "ALIAS"
    MATCH = "MATCH"
    REMOVED = "REMOVED"
    CONFLICT = "CONFLICT"
    WARN = "WARN"
    OVERRIDE = "OVERRIDE"
    RUNTIME = "RUNTIME"
    PRUNED = "PRUNED"
    REJECTED = "REJECTED"
    KEPT = "KEPT"
    REDUNDANT = "REDUNDANT"
    ERROR = "ERROR"
