"""The reconciler: policy plus overrides in, profile artefacts out.

One run is one fleet-level event: the machine-readable summary goes to
`state/profile-sync/last-run.json`.
"""

from __future__ import annotations

import difflib
import fnmatch
import json
import shutil
from dataclasses import dataclass, field
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

from .document import ConfigDocument, values_equal
from .envfile import EnvFile
from .links import LinkResult, reconcile_links
from .policy import Layer, Policy, PolicyError, Resolved, flatten, is_glob
from .status import Status

BACKUP_RETENTION = 5

# A normal outcome, not a change; shown only with --verbose.
_QUIET_STATUSES = {Status.OK, Status.KEPT, Status.REDUNDANT}


@dataclass
class Event:
    profile: str
    status: Status
    detail: str

    def line(self) -> str:
        return f"{self.profile}\t{self.status}\t{self.detail}"


@dataclass
class ProfileReport:
    name: str
    changed: bool = False
    pruned: list[str] = field(default_factory=list)
    rejected: list[tuple[str, str]] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)
    conflicts: list[str] = field(default_factory=list)
    errors: list[str] = field(default_factory=list)
    undeclared: bool = False


@dataclass
class Report:
    events: list[Event] = field(default_factory=list)
    profiles: dict[str, ProfileReport] = field(default_factory=dict)
    diffs: dict[str, str] = field(default_factory=dict)

    def add(
        self, profile: str, status: Status, detail: str, key: str | None = None
    ) -> None:
        self.events.append(Event(profile, status, detail))
        record = self.profiles[profile]
        if status == Status.PRUNED:
            record.pruned.append(key or detail)
        elif status == Status.REJECTED:
            record.rejected.append((key or "", detail))
        elif status == Status.WARN:
            record.warnings.append(detail)
        elif status == Status.CONFLICT:
            record.conflicts.append(detail)
        elif status == Status.ERROR:
            record.errors.append(detail)
        if status in {Status.OVERRIDE, Status.RUNTIME}:
            record.changed = True

    @property
    def changed(self) -> list[str]:
        return sorted(name for name, record in self.profiles.items() if record.changed)

    @property
    def rejected(self) -> int:
        return sum(len(record.rejected) for record in self.profiles.values())

    @property
    def failed(self) -> bool:
        return any(record.errors for record in self.profiles.values())

    def as_dict(self, now: datetime) -> dict[str, Any]:
        return {
            "ts": now.strftime("%Y-%m-%dT%H:%M:%SZ"),
            "changed": self.changed,
            "pruned": sum(len(record.pruned) for record in self.profiles.values()),
            "rejected": self.rejected,
            "profiles": {
                name: {
                    "changed": record.changed,
                    "pruned": record.pruned,
                    "undeclared": record.undeclared,
                    "warnings": record.warnings,
                    "conflicts": record.conflicts,
                    "errors": record.errors,
                }
                for name, record in sorted(self.profiles.items())
            },
        }


class Reconciler:
    def __init__(
        self,
        hermes_home: Path,
        policy: Policy,
        *,
        dry_run: bool = False,
        force: bool = False,
        verbose: bool = False,
        backup_retention: int = BACKUP_RETENTION,
    ) -> None:
        self.hermes_home = hermes_home
        self.policy = policy
        self.dry_run = dry_run
        self.force = force
        self.verbose = verbose
        self.backup_retention = backup_retention
        self.report = Report()
        self._run_stamp = datetime.now(UTC).strftime("%Y%m%dT%H%M%SZ")

    def run(self, only: list[str] | None = None) -> Report:
        profiles = self._discover(only)
        source_env = EnvFile(self.hermes_home / ".env").entries()

        for name in profiles:
            self.report.profiles[name] = ProfileReport(name)
            try:
                self._reconcile(name, source_env)
            except (PolicyError, OSError, ValueError) as exc:
                self.report.add(name, Status.ERROR, str(exc))

        declared = set(self.policy.profiles)
        for name in sorted(declared - set(profiles)):
            self.report.profiles[name] = ProfileReport(
                name, undeclared=True, warnings=["profile missing"]
            )
        for name in profiles:
            if name not in declared:
                self.report.profiles[name].undeclared = True
                self.report.add(name, Status.WARN, "no policy entry, defaults only")

        if not self.dry_run:
            self.prune_backups()
        return self.report

    def _discover(self, only: list[str] | None) -> list[str]:
        root = self.hermes_home / "profiles"
        if not root.is_dir():
            raise PolicyError(f"no profiles directory at {root}")
        names = sorted(
            entry.name for entry in root.iterdir() if (entry / "config.yaml").is_file()
        )
        if only:
            missing = sorted(set(only) - set(names))
            if missing:
                raise PolicyError(f"unknown profile(s): {', '.join(missing)}")
            names = [name for name in names if name in set(only)]
        return names

    def _reconcile(self, name: str, source_env: dict[str, str]) -> None:
        home = self.hermes_home / "profiles" / name
        entry = self.policy.profiles.get(name)
        override = self._load_override(name)
        resolved = self.policy.resolve(name, override)

        for kind, key in resolved.rejected:
            self.report.add(
                name,
                Status.REJECTED,
                f"{key}: locked, override ignored ({kind})",
                key=key,
            )

        document = ConfigDocument(home / "config.yaml")
        self._apply_settings(name, resolved, document)

        env = EnvFile(home / ".env")
        self._apply_env(name, resolved, env, source_env)

        if self.verbose:
            for path in resolved.redundant:
                self.report.add(name, Status.REDUNDANT, path)

        self._commit(name, home, document, env)
        self._reconcile_links(name, home / "home", entry)

    def _load_override(self, name: str) -> Layer | None:
        path = (
            self.hermes_home / "state" / "profile-sync" / "overrides" / f"{name}.json"
        )
        if not path.is_file():
            return None
        try:
            raw = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            raise PolicyError(f"{path}: not valid JSON: {exc}") from exc
        return Layer.from_raw(raw, f"override:{name}")

    def _apply_settings(
        self, name: str, resolved: Resolved, document: ConfigDocument
    ) -> None:
        for path, desired in flatten(resolved.settings).items():
            found, current = document.get(path)
            if found and values_equal(desired, current):
                continue
            status = (
                Status.RUNTIME
                if path in resolved.settings_from_override
                else Status.OVERRIDE
            )
            before = repr(current) if found else "(absent)"
            self.report.add(name, status, f"{path}: {before} -> {desired!r}", key=path)
            document.set(path, desired)

        for path in resolved.settings_unset:
            found, _ = document.get(path)
            if not found:
                continue
            if document.delete(path):
                self.report.add(name, Status.PRUNED, path, key=path)

    def _apply_env(
        self,
        name: str,
        resolved: Resolved,
        env: EnvFile,
        source_env: dict[str, str],
    ) -> None:
        current = env.entries()
        explicit = set(resolved.env_set)

        for pattern in resolved.env_unset:
            for key in sorted(current):
                if not fnmatch.fnmatchcase(key, pattern):
                    continue
                if key in explicit:
                    # An explicit set wins over a prune rule for the same key.
                    continue
                if key in resolved.env_keep:
                    self.report.add(
                        name, Status.KEPT, f"{key}: exempt from {pattern}", key=key
                    )
                    continue
                if (
                    key in resolved.lock_env
                    and pattern in resolved.env_unset_from_override
                ):
                    self.report.add(
                        name,
                        Status.REJECTED,
                        f"{key}: locked, override ignored",
                        key=key,
                    )
                    continue
                self._prune_env(name, env, key, current[key], source_env, pattern)

        for key in resolved.env_inherit:
            value = source_env.get(key)
            if value is None:
                self.report.add(
                    name, Status.WARN, f"{key}: missing in container env", key=key
                )
                continue
            self._write_env(name, env, key, value, current, Status.OVERRIDE)

        for key, spec in resolved.env_set.items():
            value = self._resolve_env_value(name, spec)
            if value is None:
                continue
            status = (
                Status.RUNTIME
                if key in resolved.env_set_from_override
                else Status.OVERRIDE
            )
            self._write_env(name, env, key, value, current, status)

    def _resolve_env_value(self, name: str, spec: Any) -> str | None:
        if isinstance(spec, str):
            return spec
        if isinstance(spec, dict) and "secret" in spec:
            path = Path(spec["secret"])
            try:
                return path.read_text(encoding="utf-8").rstrip("\n")
            except OSError as exc:
                self.report.add(name, Status.ERROR, f"secret {path}: {exc.strerror}")
                return None
        self.report.add(name, Status.ERROR, f"unusable env.set value {spec!r}")
        return None

    def _prune_env(
        self,
        name: str,
        env: EnvFile,
        key: str,
        value: str,
        source_env: dict[str, str],
        pattern: str,
    ) -> None:
        source = source_env.get(key)
        if source is not None and source != value:
            self.report.add(
                name, Status.WARN, f"{key}: local value differs, kept", key=key
            )
            return
        if source is None and is_glob(pattern):
            self.report.add(
                name, Status.WARN, f"{key}: cannot verify, no source value", key=key
            )
            return
        env.delete(key)
        self.report.add(name, Status.PRUNED, key, key=key)

    def _write_env(
        self,
        name: str,
        env: EnvFile,
        key: str,
        value: str,
        current: dict[str, str],
        status: Status,
    ) -> None:
        if current.get(key) == value:
            return
        before = "set" if key in current else "absent"
        self.report.add(name, status, f"{key}: {before} -> set", key=key)
        env.set(key, value)

    def _reconcile_links(
        self, name: str, profile_home: Path, entry: Layer | None
    ) -> None:
        links = self.policy.links.for_profile(name, entry.cls if entry else None)
        if not links:
            return
        for result in reconcile_links(
            profile_home,
            links.managed,
            excluded=links.excluded,
            force=self.force,
            backup=lambda target, path: self._backup_forced(name, target, path),
            dry_run=self.dry_run,
        ):
            self.report.add(
                name, result.status, self._link_detail(result), key=result.target
            )

    @staticmethod
    def _link_detail(result: LinkResult) -> str:
        if result.detail:
            return f"{result.target}: {result.detail}"
        return result.target

    def _backup_forced(self, name: str, target: str, path: Path) -> Path:
        destination = self._backup_dir(name) / "links" / target
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(str(path), str(destination))
        return destination

    def _commit(
        self, name: str, home: Path, document: ConfigDocument, env: EnvFile
    ) -> None:
        changes: dict[str, str] = {}
        if document.changed():
            changes["config.yaml"] = document.text()
        if env.changed():
            changes[".env"] = env.text()
        if not changes:
            return

        self.report.profiles[name].changed = True
        if self.dry_run:
            for filename, text in changes.items():
                path = home / filename
                original = path.read_text(encoding="utf-8") if path.exists() else ""
                self.report.diffs[f"{name}/{filename}"] = "".join(
                    difflib.unified_diff(
                        original.splitlines(keepends=True),
                        text.splitlines(keepends=True),
                        fromfile=f"{name}/{filename}",
                        tofile=f"{name}/{filename} (desired)",
                    )
                )
            return

        backup_dir = self._backup_dir(name)
        for filename, text in changes.items():
            path = home / filename
            if path.exists():
                backup_dir.mkdir(parents=True, exist_ok=True)
                shutil.copy2(path, backup_dir / filename)
            path.write_text(text, encoding="utf-8")

    def _backup_dir(self, name: str) -> Path:
        return self.hermes_home / "backups" / "profile-sync" / self._run_stamp / name

    def prune_backups(self) -> None:
        """Keep the newest N run directories and roll the rest off."""
        root = self.hermes_home / "backups" / "profile-sync"
        if not root.is_dir():
            return
        runs = sorted(entry for entry in root.iterdir() if entry.is_dir())
        for stale in runs[: -self.backup_retention]:
            shutil.rmtree(stale, ignore_errors=True)

    def write_state(self, now: datetime | None = None) -> Path:
        path = self.hermes_home / "state" / "profile-sync" / "last-run.json"
        path.parent.mkdir(parents=True, exist_ok=True)
        stamp = now or datetime.now(UTC)
        path.write_text(
            json.dumps(self.report.as_dict(stamp), indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )
        return path


def render(report: Report, *, verbose: bool, quiet: bool) -> str:
    """Human output: one line per outcome, nothing at all when the fleet is clean.

    `--quiet` still prints a failure: a run that rejected an override or could not read
    a secret must not be silent about it.
    """
    if quiet:
        keep = {Status.ERROR, Status.REJECTED, Status.CONFLICT}
        return "".join(
            f"{event.line()}\n" for event in report.events if event.status in keep
        )
    return "".join(
        f"{event.line()}\n"
        for event in report.events
        if verbose or event.status not in _QUIET_STATUSES
    )


def render_diffs(report: Report) -> str:
    return "".join(
        text if text.endswith("\n") else f"{text}\n" for text in report.diffs.values()
    )
