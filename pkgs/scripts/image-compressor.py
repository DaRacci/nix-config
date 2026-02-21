#!/usr/bin/env python3

from __future__ import annotations

import argparse
import csv
import hashlib
import os
import signal
import subprocess
import tempfile
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Tuple

import magic
from PIL import Image, UnidentifiedImageError
from rich.console import Console
from rich.progress import (
    BarColumn,
    Progress,
    SpinnerColumn,
    TextColumn,
    TimeElapsedColumn,
)
from rich.table import Table

DEFAULT_CACHE_DIR = Path.home() / ".cache" / "image-savings"
DEFAULT_JOBS = 8
QUALITY = 95
IMAGE_EXTENSIONS = {
    ".jpg",
    ".jpeg",
    ".png",
    ".webp",
    ".tiff",
    ".tif",
    ".bmp",
    ".heic",
    ".heif",
    ".avif",
}


STOP_EVENT = threading.Event()
SAVE_LOCK = threading.Lock()
CONSOLE = Console()


@dataclass
class CacheEntry:
    mtime_ns: int
    size: int
    sha256: str
    file_type: str


@dataclass
class FileResult:
    path: Path
    rel_path: str
    file_type: str
    original_size: int
    webp_size: int
    action: str


class HashCache:
    def __init__(self, cache_file: Path) -> None:
        self.cache_file = cache_file
        self.entries: Dict[str, CacheEntry] = {}
        self.modified = False

    def load(self) -> int:
        if not self.cache_file.exists():
            return 0
        loaded = 0
        with self.cache_file.open("r", encoding="utf-8", newline="") as handle:
            reader = csv.reader(handle, delimiter="\t")
            for row in reader:
                if not row or row[0].startswith("#"):
                    continue
                if len(row) < 4:
                    continue
                path, mtime_ns, size, sha256, *rest = row
                file_type = rest[0] if rest else "unknown"
                self.entries[path] = CacheEntry(
                    mtime_ns=int(mtime_ns),
                    size=int(size),
                    sha256=sha256,
                    file_type=file_type or "unknown",
                )
                loaded += 1
        return loaded

    def lookup(self, path: Path) -> Optional[CacheEntry]:
        stat = path.stat()
        entry = self.entries.get(str(path))
        if entry is None:
            return None
        if entry.mtime_ns != stat.st_mtime_ns or entry.size != stat.st_size:
            return None
        return entry

    def update(self, path: Path, entry: CacheEntry) -> None:
        self.entries[str(path)] = entry
        self.modified = True

    def save(self) -> None:
        if not self.modified:
            return
        self.cache_file.parent.mkdir(parents=True, exist_ok=True)
        fd, tmp_name = tempfile.mkstemp(
            prefix=self.cache_file.name + ".",
            dir=self.cache_file.parent,
        )
        os.close(fd)
        tmp_path = Path(tmp_name)
        try:
            with tmp_path.open("w", encoding="utf-8", newline="") as handle:
                writer = csv.writer(
                    handle,
                    delimiter="\t",
                    lineterminator="\n",
                )
                writer.writerow(
                    [
                        "# image-savings hash cache — path",
                        "mtime_ns",
                        "size",
                        "sha256",
                        "type",
                    ]
                )
                for path_str in sorted(self.entries):
                    entry = self.entries[path_str]
                    writer.writerow(
                        [
                            path_str,
                            entry.mtime_ns,
                            entry.size,
                            entry.sha256,
                            entry.file_type,
                        ]
                    )
            tmp_path.replace(self.cache_file)
            self.modified = False
        finally:
            if tmp_path.exists():
                tmp_path.unlink(missing_ok=True)


class App:
    def __init__(self, args: argparse.Namespace) -> None:
        self.input_path = args.directory.resolve()
        self.target_dir = (
            self.input_path if self.input_path.is_dir() else self.input_path.parent
        )

        self.apply = args.apply
        self.jobs = max(1, args.jobs)
        self.debug_enabled = args.debug
        self.cache_dir = (
            args.cache_dir.resolve() if args.cache_dir else DEFAULT_CACHE_DIR
        )
        self.cache_dir.mkdir(parents=True, exist_ok=True)
        self.hash_cache = HashCache(self.cache_dir / "hashcache.tsv")
        self.images: List[Path] = []
        self.hash_hits = 0
        self.conversion_hits = 0
        self.errors = 0
        self.applied = 0
        self.skipped_no_gain = 0
        self.progress: Optional[Progress] = None

    def warn(self, message: str) -> None:
        CONSOLE.print(f"[warn] {message}", style="yellow")

    def save_cache(self) -> None:
        with SAVE_LOCK:
            self.hash_cache.save()

    def format_webp_cell(self, webp_size: int, original_size: int) -> str:
        saved = original_size - webp_size
        if saved <= 0:
            return "no gain"
        webp_text = self.human_bytes(webp_size)
        pct_text = self.savings_pct(original_size, saved)
        return f"{webp_text} ({pct_text})"

    def discover_images(self) -> None:
        if self.input_path.is_file():
            self.images = [self.input_path]
        else:
            self.images = sorted(
                path
                for path in self.target_dir.rglob("*")
                if path.is_file() and path.suffix.lower() in IMAGE_EXTENSIONS
            )
        if not self.images:
            CONSOLE.print(f"No image files found under '{self.input_path}'.")
            raise SystemExit(0)
        if self.input_path.is_file():
            CONSOLE.print(f"Found 1 image: '{self.input_path}'.")
        else:
            CONSOLE.print(
                f"Found {len(self.images)} image(s) under '{self.target_dir}'."
            )

    def file_hash(self, path: Path) -> str:
        digest = hashlib.sha256()
        with path.open("rb") as handle:
            for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                digest.update(chunk)
        return digest.hexdigest()

    def file_type(self, path: Path) -> str:
        try:
            mime = magic.from_file(path, mime=True)
        except (FileNotFoundError, OSError, magic.MagicException):
            return "unknown"

        return mime.removeprefix("image/") if mime.startswith("image/") else "unknown"

    def compute_missing_hashes(
        self,
        missing: List[Path],
    ) -> Dict[Path, CacheEntry]:
        results: Dict[Path, CacheEntry] = {}
        if not missing:
            return results
        self.warn(f"hash misses={len(missing)}")
        self.run_progress(
            "Hashing",
            missing,
            self.hash_worker,
            None,
            results=results,
            description_suffix="sha256",
        )
        computed = len(results)
        failed = len(missing) - computed
        suffix = f", {failed} failed (skipped)" if failed else ""
        CONSOLE.print(f"sha256: {computed} computed{suffix}.")
        return results

    def hash_worker(
        self, path: Path, _state: object
    ) -> Tuple[Path, Optional[CacheEntry]]:
        if STOP_EVENT.is_set():
            return path, None
        try:
            stat = path.stat()
            entry = CacheEntry(
                mtime_ns=stat.st_mtime_ns,
                size=stat.st_size,
                sha256=self.file_hash(path),
                file_type=self.file_type(path),
            )
            return path, entry
        except OSError as exc:
            self.warn(f"hash failed: {path}: {exc}")
            return path, None

    def cache_hashes(self) -> Tuple[Dict[Path, str], Dict[Path, str]]:
        img_hash: Dict[Path, str] = {}
        img_type: Dict[Path, str] = {}
        missing: List[Path] = []

        for path in self.images:
            entry = self.hash_cache.lookup(path)
            if entry is None:
                missing.append(path)
                continue
            img_hash[path] = entry.sha256
            img_type[path] = entry.file_type
            self.hash_hits += 1

        CONSOLE.print(f"Hash cache: {self.hash_hits} hit(s), {len(missing)} miss(es).")

        computed = self.compute_missing_hashes(missing)
        for path, entry in computed.items():
            img_hash[path] = entry.sha256
            img_type[path] = entry.file_type
            self.hash_cache.update(path, entry)
        return img_hash, img_type

    def convert_one(self, path: Path, sha256: str) -> bool:
        if STOP_EVENT.is_set():
            return False
        output = self.cache_dir / f"{sha256}.webp"
        if output.exists():
            return True
        result = subprocess.run(
            [
                "convert",
                str(path),
                "-quality",
                str(QUALITY),
                f"webp:{output}",
            ],
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        return result.returncode == 0 and output.exists()

    def convert_images(
        self,
        img_hash: Dict[Path, str],
        img_type: Dict[Path, str],
    ) -> None:
        missing = [
            path
            for path in self.images
            if path in img_hash
            and img_type.get(path) != "webp"
            and not (self.cache_dir / f"{img_hash[path]}.webp").exists()
        ]

        self.conversion_hits = len(img_hash) - len(missing)
        CONSOLE.print(
            f"Conversion cache: {self.conversion_hits} hit(s), {len(missing)} miss(es)."
        )
        if not missing:
            return
        convert_results: Dict[Path, bool] = {}
        self.warn(f"conversion misses={len(missing)}")
        self.run_progress(
            "Converting",
            missing,
            self.convert_worker,
            img_hash,
            results=convert_results,
            description_suffix="image(s)",
        )
        failed = 0
        for path, ok in convert_results.items():
            if not ok:
                failed += 1
                self.errors += 1
                self.warn(f"convert failed: {path}")
        CONSOLE.print("Conversion complete.")
        if failed:
            CONSOLE.print(f"Conversion failures: {failed}")

    def convert_worker(
        self,
        path: Path,
        img_hash: Dict[Path, str],
    ) -> Tuple[Path, bool]:
        return path, self.convert_one(path, img_hash[path])

    def verify_webp(self, path: Path) -> bool:
        try:
            with Image.open(path) as img:
                img.verify()
            with Image.open(path) as img:
                img.load()
            return True
        except (OSError, UnidentifiedImageError) as exc:
            self.warn(f"invalid webp: {path}: {exc}")
            return False

    def apply_one(self, path: Path, sha256: str) -> str:
        cached = self.cache_dir / f"{sha256}.webp"
        if not cached.exists():
            return "failed"
        if not self.verify_webp(cached):
            return "failed"
        stat = path.stat()
        fd, tmp_name = tempfile.mkstemp(
            prefix=".img_savings_",
            suffix=".tmp",
            dir=path.parent,
        )
        os.close(fd)
        tmp_path = Path(tmp_name)
        try:
            try:
                cached.replace(tmp_path)
            except OSError as exc:
                if getattr(exc, "errno", None) != 18:
                    raise
                tmp_path.write_bytes(cached.read_bytes())
                cached.unlink(missing_ok=True)
            tmp_path.replace(path)
            os.utime(path, ns=(stat.st_atime_ns, stat.st_mtime_ns))
            return "replaced"
        except OSError as exc:
            self.warn(f"apply failed: {path}: {exc}")
            return "failed"
        finally:
            tmp_path.unlink(missing_ok=True)

    def apply_worker(
        self,
        path: Path,
        img_hash: Dict[Path, str],
    ) -> Tuple[Path, str]:
        status = self.apply_one(path, img_hash[path])
        return path, status

    def display_width(self, text: str) -> int:
        width = 0
        for char in text:
            if char.isascii():
                width += 1
            else:
                width += 1
        return width

    def truncate_display(self, text: str, width: int) -> str:
        if len(text) <= width:
            return text
        return text[: max(0, width - 3)] + "..."

    def pad_display(self, text: str, width: int, align: str = "left") -> str:
        if len(text) >= width:
            return text
        pad = " " * (width - len(text))
        return text + pad if align == "left" else pad + text

    def human_bytes(self, size: int) -> str:
        if size >= 1073741824:
            return f"{size / 1073741824:8.2f} GB"
        if size >= 1048576:
            return f"{size / 1048576:8.2f} MB"
        if size >= 1024:
            return f"{size / 1024:8.2f} KB"
        return f"{size:8d} B"

    def savings_pct(self, original: int, saved: int) -> str:
        if original == 0 or saved <= 0:
            return "—"
        return f"{(saved / original) * 100:.1f}%"

    def webp_cell(self, webp_size: int, original_size: int) -> str:
        saved = original_size - webp_size
        if saved <= 0:
            return "no gain"
        return self.format_webp_cell(webp_size, original_size)

    def collect_results(
        self,
        img_hash: Dict[Path, str],
        img_type: Dict[Path, str],
    ) -> List[FileResult]:
        results: List[FileResult] = []
        to_apply: List[Tuple[Path, str]] = []

        for path in self.images:
            sha256 = img_hash.get(path)
            if not sha256:
                self.errors += 1
                self.warn(f"missing hash: {path}")
                continue

            detected_type = img_type.get(path, "unknown")
            original_size = path.stat().st_size
            cached = self.cache_dir / f"{sha256}.webp"
            if detected_type == "webp":
                webp_size = original_size
            elif cached.exists():
                webp_size = cached.stat().st_size
            else:
                webp_size = original_size
            if webp_size > original_size:
                webp_size = original_size
            if (
                self.apply
                and detected_type != "webp"
                and cached.exists()
                and webp_size < original_size
            ):
                to_apply.append((path, sha256))
            display_root = (
                self.input_path.parent if self.input_path.is_file() else self.target_dir
            )
            results.append(
                FileResult(
                    path=path,
                    rel_path=self.truncate_path(path.relative_to(display_root), 72),
                    file_type=detected_type,
                    original_size=original_size,
                    webp_size=webp_size,
                    action="",
                )
            )

        apply_results: Dict[Path, str] = {}
        if self.apply and to_apply:
            self.run_progress(
                "Applying",
                [path for path, _ in to_apply],
                self.apply_worker,
                img_hash,
                results=apply_results,
                description_suffix="replacement(s)",
            )
            for path, status in apply_results.items():
                if status == "replaced":
                    self.applied += 1
                else:
                    self.errors += 1

        for result in results:
            saved = result.original_size - result.webp_size
            if self.apply:
                if saved > 0:
                    result.action = (
                        "✓ replaced"
                        if apply_results.get(result.path) == "replaced"
                        else "✗ failed"
                    )
                else:
                    result.action = "skipped"
                    self.skipped_no_gain += 1
            else:
                if result.file_type == "webp":
                    result.action = "skip webp"
                else:
                    result.action = "would replace" if saved > 0 else "no gain"
        return results

    def render_results(self, results: List[FileResult]) -> None:
        table = Table(show_header=True, header_style="bold", expand=True)
        table.add_column("File", overflow="ellipsis", ratio=5, no_wrap=True)
        table.add_column("Original", justify="right", no_wrap=True, min_width=12)
        table.add_column("→ WebP (95%)", justify="right", no_wrap=True, min_width=18)
        table.add_column("Type", no_wrap=True, min_width=8)
        table.add_column("Action", no_wrap=True, min_width=13)

        for item in results:
            table.add_row(
                item.rel_path,
                self.human_bytes(item.original_size),
                self.webp_cell(item.webp_size, item.original_size),
                item.file_type,
                item.action,
            )

        CONSOLE.print()
        CONSOLE.print(table)

        would_replace = sum(1 for item in results if item.action == "would replace")
        CONSOLE.print()
        CONSOLE.print(f"Images scanned: {len(self.images)}")
        CONSOLE.print(f"Hash cache hits: {self.hash_hits}")
        CONSOLE.print(f"Conversion hits: {self.conversion_hits}")
        CONSOLE.print(f"Would replace: {would_replace}")

        if self.errors:
            CONSOLE.print(f"Errors: {self.errors}")
        total_original = sum(item.original_size for item in results)
        total_webp = sum(item.webp_size for item in results)
        saved_total = total_original - total_webp
        CONSOLE.print(
            f"Total original size: {self.human_bytes(total_original).strip()}"
        )
        CONSOLE.print()
        CONSOLE.print(
            f"→ WebP (95%): {self.human_bytes(saved_total).strip()} saved "
            f"({self.savings_pct(total_original, saved_total)})"
        )
        CONSOLE.print()
        if self.apply:
            CONSOLE.print(f"Files replaced: {self.applied}")
            CONSOLE.print(f"Skipped (no gain): {self.skipped_no_gain}")
            CONSOLE.print(f"\n✓  Done. Cache at: {self.cache_dir}\n")
        else:
            CONSOLE.print(
                "ℹ️  Dry-run — no files modified. Use --apply to convert in-place."
            )
            CONSOLE.print(f"   Cache stored at: {self.cache_dir}\n")

    def run_progress(
        self,
        label: str,
        items: List[Path],
        worker,
        state,
        results: Optional[Dict[Path, object]] = None,
        description_suffix: str = "items",
    ) -> None:
        total = len(items)
        if total == 0:
            return
        progress = Progress(
            SpinnerColumn(),
            TextColumn("{task.description}"),
            BarColumn(bar_width=None),
            TextColumn("{task.completed}/{task.total}"),
            TimeElapsedColumn(),
            console=CONSOLE,
            transient=False,
            refresh_per_second=12,
        )
        task_id = progress.add_task(f"{label} {description_suffix}", total=total)
        with progress, ThreadPoolExecutor(max_workers=self.jobs) as executor:
            futures = [executor.submit(worker, path, state) for path in items]
            for future in as_completed(futures):
                path, status = future.result()
                if results is not None:
                    results[path] = status
                progress.advance(task_id, 1)

    def truncate_path(self, rel_path: Path, max_width: int) -> str:
        parts = list(rel_path.parts)
        if not parts:
            return ""

        rendered = "/".join(parts)
        if len(rendered) <= max_width:
            return rendered

        def shrink_piece(piece: str, width: int = 3) -> str:
            if len(piece) <= width:
                return piece
            return piece[: max(1, width - 1)] + ".."

        filename = parts[-1]
        parents = parts[:-1]
        shortened_parents = [shrink_piece(part) for part in parents]
        parent_prefix = "/".join(shortened_parents)
        if parent_prefix:
            rendered = f"{parent_prefix}/{filename}"
        else:
            rendered = filename
        if len(rendered) <= max_width:
            return rendered

        filename_marker = "…"
        available = max_width - (len(parent_prefix) + (1 if parent_prefix else 0))
        if available <= 0:
            return rendered[:max_width]
        if available <= len(filename_marker) + 1:
            return (
                f"{parent_prefix}/{filename[:1]}{filename_marker}"
                if parent_prefix
                else f"{filename[:1]}{filename_marker}"
            )

        keep = max(1, available - len(filename_marker))
        filename = filename[:keep] + filename_marker
        return f"{parent_prefix}/{filename}" if parent_prefix else filename

    def run(self) -> int:
        loaded = self.hash_cache.load()
        self.discover_images()
        CONSOLE.print("Checking cache...")

        if loaded:
            CONSOLE.print(f"  (loaded {loaded} cached hashes)")
        img_hash, img_type = self.cache_hashes()
        self.convert_images(img_hash, img_type)

        results = self.collect_results(img_hash, img_type)
        self.render_results(results)
        self.save_cache()
        return 0


def parse_args(argv: Optional[Iterable[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=("Compress images to cached WebP and optionally replace originals.")
    )
    parser.add_argument("directory", type=Path)
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Convert files in-place using cached WebP output",
    )
    parser.add_argument(
        "--cache-dir",
        type=Path,
        help="Cache directory (default: ~/.cache/image-savings)",
    )
    parser.add_argument(
        "--jobs",
        type=int,
        default=DEFAULT_JOBS,
        help=f"Parallel worker count (default: {DEFAULT_JOBS})",
    )
    parser.add_argument("--debug", action="store_true", help="Verbose logging")
    return parser.parse_args(argv)


def install_signal_handlers(app: App) -> None:
    def handle_interrupt(_signum: int, _frame: object) -> None:
        STOP_EVENT.set()
        CONSOLE.print("\nInterrupted — cleaning up.", style="yellow")
        app.save_cache()
        raise SystemExit(130)

    signal.signal(signal.SIGINT, handle_interrupt)
    signal.signal(signal.SIGTERM, handle_interrupt)


def main(argv: Optional[Iterable[str]] = None) -> int:
    args = parse_args(argv)
    if not args.directory.exists():
        CONSOLE.print(f"Error: '{args.directory}' does not exist.", style="red")
        return 1
    app = App(args)
    install_signal_handlers(app)
    try:
        return app.run()
    finally:
        app.save_cache()


if __name__ == "__main__":
    raise SystemExit(main())
