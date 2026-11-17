"""Link reconciliation for profile homes.

Every status is decided from the filesystem: the source has to exist, and the target's
resolved path decides between a fresh link, a repoint, a replacement and a conflict.
A real file or directory is replaced only when its content is identical to the source
(MATCH), or with `--force` after the original is moved into the backup root (CONFLICT).
An excluded spec unlinks the symlink that resolves to its own source.
"""

from __future__ import annotations

import hashlib
import os
import shutil
from collections.abc import Callable, Iterable
from dataclasses import dataclass
from pathlib import Path

from .policy import LinkSpec
from .status import Status

# Above either budget a tree is reported as CONFLICT instead of compared, so --force can
# move it into place without a full read.
MAX_COMPARE_FILES = 20000
MAX_COMPARE_BYTES = 1024 * 1024 * 1024
_CHUNK = 1024 * 1024


@dataclass(frozen=True)
class LinkResult:
    target: str
    status: Status
    detail: str = ""

    @property
    def changed(self) -> bool:
        return self.status in {
            Status.NEW,
            Status.RELINK,
            Status.ALIAS,
            Status.MATCH,
            Status.REMOVED,
        }


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        while chunk := handle.read(_CHUNK):
            digest.update(chunk)
    return digest.hexdigest()


def _manifest(root: Path) -> list[tuple[str, str]] | None:
    """Relative paths with a content fingerprint, or None when the tree is too large."""
    manifest: list[tuple[str, str]] = []
    total = 0
    for directory, dirnames, filenames in os.walk(root, followlinks=False):
        dirnames.sort()
        filenames.sort()
        base = Path(directory)
        for name in dirnames + filenames:
            path = base / name
            relative = str(path.relative_to(root))
            if path.is_symlink():
                manifest.append((relative, f"link:{os.readlink(path)}"))
                continue
            if path.is_dir():
                continue
            size = path.stat().st_size
            total += size
            if len(manifest) > MAX_COMPARE_FILES or total > MAX_COMPARE_BYTES:
                return None
            manifest.append((relative, f"{size}:{_sha256(path)}"))
    return sorted(manifest)


def identical(target: Path, source: Path) -> bool | None:
    """True when both paths hold the same content, False when they differ, None when the
    tree is larger than the compare budget."""
    if target.is_symlink() or source.is_symlink():
        return os.path.realpath(target) == os.path.realpath(source)

    if target.is_file() != source.is_file():
        return False

    if target.is_file():
        if target.stat().st_size != source.stat().st_size:
            return False
        if target.stat().st_size > MAX_COMPARE_BYTES:
            return None
        return _sha256(target) == _sha256(source)

    target_manifest = _manifest(target)
    source_manifest = _manifest(source)
    if target_manifest is None or source_manifest is None:
        return None

    return target_manifest == source_manifest


def _remove(path: Path) -> None:
    """Delete one leaf: a link, a file, or a directory tree."""
    if path.is_symlink() or not path.is_dir():
        path.unlink()
    else:
        shutil.rmtree(path)


def _link(source: Path, target: Path) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    os.symlink(source, target)


def reconcile_links(
    profile_home: Path,
    specs: Iterable[LinkSpec],
    *,
    excluded: Iterable[LinkSpec] = (),
    force: bool = False,
    backup: Callable[[str, Path], Path] | None = None,
    dry_run: bool = False,
) -> list[LinkResult]:
    """Reconcile one profile home against a link list.

    `excluded` are specs the policy drops for this profile: an existing link to their
    source is unlinked.

    `backup` is called only for a `--force` conversion and must move the original
    path out of the way before returning.
    """
    results = [
        _reconcile_one(profile_home, spec, force=force, backup=backup, dry_run=dry_run)
        for spec in specs
    ]
    for spec in excluded:
        result = _unlink_excluded(profile_home, spec, dry_run=dry_run)
        if result is not None:
            results.append(result)
    return results


def _inside(path: Path, root: Path) -> bool:
    """True when `path` really lives under `root` once links are resolved."""
    real_root = os.path.realpath(root)
    real_path = os.path.realpath(path)
    return real_path == real_root or real_path.startswith(real_root + os.sep)


def _unlink_excluded(
    profile_home: Path, spec: LinkSpec, *, dry_run: bool
) -> LinkResult | None:
    """Unlink a spec the profile excludes, or explain why it is left alone.

    Only a symlink resolving to the spec's own source is removed. A real file is the
    profile's own data, and a link to somewhere else belongs to someone else: both are
    reported and untouched.
    """
    target = profile_home / spec.target
    if not os.path.lexists(target):
        return None

    if not _inside(target.parent, profile_home):
        return LinkResult(
            spec.target,
            Status.CONFLICT,
            "excluded, but resolves outside the profile home; not removing",
        )
    if not target.is_symlink():
        return LinkResult(
            spec.target, Status.WARN, "excluded, but not a link; left in place"
        )

    source = Path(spec.source)
    direct = os.readlink(target)
    if direct != str(source) and os.path.realpath(target) != os.path.realpath(source):
        return LinkResult(
            spec.target,
            Status.WARN,
            "excluded, but the link points elsewhere; left in place",
        )

    if dry_run:
        return LinkResult(spec.target, Status.REMOVED, "dry-run: would unlink")
    target.unlink()
    return LinkResult(spec.target, Status.REMOVED)


def _reconcile_one(
    profile_home: Path,
    spec: LinkSpec,
    *,
    force: bool,
    backup: Callable[[str, Path], Path] | None,
    dry_run: bool,
) -> LinkResult:
    target = profile_home / spec.target
    source = Path(spec.source)

    if not os.path.exists(source):
        return LinkResult(spec.target, Status.WARN, "source missing")

    if not os.path.lexists(target):
        if not dry_run:
            _link(source, target)
        return LinkResult(spec.target, Status.NEW)

    # A parent that resolves into the source makes the leaf a file of the source tree, so
    # unlinking it would delete the canonical copy.
    if not _inside(target.parent, profile_home):
        return LinkResult(
            spec.target,
            Status.CONFLICT,
            "resolves into the source through a parent link; not converting",
        )

    if target.is_symlink():
        direct = os.readlink(target)
        if direct == str(source):
            return LinkResult(spec.target, Status.OK)
        if os.path.realpath(target) == os.path.realpath(source):
            # Same file, different spelling of the path. The leaf is a link inside the
            # profile home, so replacing it loses nothing.
            if not dry_run:
                target.unlink()
                _link(source, target)
            return LinkResult(spec.target, Status.ALIAS)
        if not dry_run:
            target.unlink()
            _link(source, target)
        return LinkResult(spec.target, Status.RELINK)

    same = identical(target, source)
    if same is True:
        if not dry_run:
            _remove(target)
            _link(source, target)
        return LinkResult(spec.target, Status.MATCH)

    detail = "too large to compare" if same is None else "content differs"
    if not force or backup is None:
        return LinkResult(spec.target, Status.CONFLICT, f"{detail}; use --force")
    if not dry_run:
        backup(spec.target, target)
        _link(source, target)
    return LinkResult(spec.target, Status.CONFLICT, f"{detail}; converted with --force")
