#!/usr/bin/env python3

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import os
import shutil
import signal
import subprocess
import tempfile
import threading
import time
from collections.abc import Callable, Iterable
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass
from pathlib import Path
from typing import TypeVar, final

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
IMAGE_QUALITY = 95
VIDEO_QUALITY = 30
VIDEO_PRESET = "6"
VIDEO_TUNE = "vq"
VIDEO_MAX_WIDTH = 3840
VIDEO_MAX_HEIGHT = 2160
VIDEO_AUDIO_COPY_MASK = "aac,ac3"
VIDEO_AUDIO_FALLBACK = "av_aac"
VIDEO_AUDIO_ENCODERS = "av_aac,copy:ac3"
VIDEO_AUDIO_BITRATES = "160,640"
VIDEO_AUDIO_MIXDOWN = "stereo,none"
VIDEO_AUDIO_SAMPLERATES = "auto,auto"
VIDEO_MIME_ALIASES = {
    "application/mp4",
}
TARGET_IMAGE_TYPE = "webp"
TARGET_VIDEO_TYPE = "av1"


STOP_EVENT = threading.Event()
SAVE_LOCK = threading.Lock()
CONSOLE = Console()
RESULT_T = TypeVar("RESULT_T")
STATE_T = TypeVar("STATE_T")

SEGMENT_DURATION = 5  # seconds
SEGMENT_POSITIONS = [0.25, 0.5, 0.75]  # fractions of video duration


@dataclass
class VideoSampleEstimate:
    segment_sizes: list[int]
    original_segments: list[int]

    def avg_ratio(self) -> float:
        """Avg encoded/original ratio across segments."""
        if not self.original_segments:
            return 1.0
        return sum(self.segment_sizes) / sum(self.original_segments)

    def avg_savings_pct(self) -> float:
        """Avg savings percent (1 - ratio) * 100."""
        return (1.0 - self.avg_ratio()) * 100.0

    def will_expand(self) -> bool:
        """True if avg expansion >= 5%."""
        return self.avg_ratio() > 1.05


@dataclass
class CacheEntry:
    mtime_ns: int
    size: int
    sha256: str
    file_type: str
    done: bool = False
    video_estimate_json: str = ""  # JSON serialized VideoSampleEstimate


@dataclass
class FileResult:
    path: Path
    rel_path: str
    file_type: str
    original_size: int
    optimized_size: int
    action: str
    estimate: VideoSampleEstimate | None = None


@dataclass
class ApplyResult:
    status: str
    entry: CacheEntry | None = None


@dataclass
class HandBrakeProgress:
    fraction: float
    eta_seconds: int | None
    current_pass: int
    pass_count: int


@dataclass
class VideoSampleProgress:
    progress: HandBrakeProgress
    elapsed: float
    sample_index: int
    sample_count: int
    sample_duration: float


@final
class HashCache:
    def __init__(self, cache_file: Path) -> None:
        self.cache_file = cache_file
        self.entries: dict[str, CacheEntry] = {}
        self.modified = False

    @staticmethod
    def parse_done(value: str) -> bool:
        return value.strip().lower() in {"1", "true", "yes", "y", "done"}

    @staticmethod
    def estimate_to_json(est: VideoSampleEstimate | None) -> str:
        """Serialize VideoSampleEstimate to JSON or return empty string if None."""
        if est is None:
            return ""
        try:
            data = {
                "segment_sizes": est.segment_sizes,
                "original_segments": est.original_segments,
            }
            return json.dumps(data)
        except (OSError, ValueError, TypeError):
            return ""

    @staticmethod
    def json_to_estimate(s: str) -> VideoSampleEstimate | None:
        """Deserialize JSON to VideoSampleEstimate or return None if invalid."""
        if not s or not s.strip():
            return None
        try:
            data = json.loads(s)
            return VideoSampleEstimate(
                segment_sizes=data.get("segment_sizes", []),
                original_segments=data.get("original_segments", []),
            )
        except (OSError, ValueError, TypeError):
            return None

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
                done = self.parse_done(rest[1]) if len(rest) > 1 else False
                video_estimate_json = rest[2] if len(rest) > 2 else ""
                entry = CacheEntry(
                    mtime_ns=int(mtime_ns),
                    size=int(size),
                    sha256=sha256,
                    file_type=file_type or "unknown",
                    done=done,
                )
                entry.video_estimate_json = video_estimate_json
                self.entries[path] = entry
                loaded += 1
        return loaded

    def lookup(self, path: Path) -> CacheEntry | None:
        try:
            stat = path.stat()
        except OSError:
            return None
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
                        "done",
                        "video_estimate_json",
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
                            1 if entry.done else 0,
                            entry.video_estimate_json,
                        ]
                    )
            _ = tmp_path.replace(self.cache_file)
            self.modified = False
        finally:
            if tmp_path.exists():
                tmp_path.unlink(missing_ok=True)


@final
class App:
    def __init__(self, args: argparse.Namespace) -> None:
        self.input_path: Path = args.directory.resolve()
        self.target_dir = (
            self.input_path if self.input_path.is_dir() else self.input_path.parent
        )
        self.apply: bool = args.apply
        self.force_expand: bool = args.force_expand
        self.estimate_only: bool = args.estimate_only
        self.jobs = max(1, args.jobs)
        self.debug_enabled: bool = args.debug
        self.cache_dir: Path = (
            args.cache_dir.resolve() if args.cache_dir else DEFAULT_CACHE_DIR
        )
        self.cache_dir.mkdir(parents=True, exist_ok=True)
        self.hash_cache = HashCache(self.cache_dir / "hashcache.tsv")
        self.media_files: list[Path] = []
        self.hash_hits = 0
        self.conversion_hits = 0
        self.errors = 0
        self.applied = 0
        self.skipped_no_gain = 0
        self.skipped_expansion = 0
        self.progress: Progress | None = None
        self.video_encode_times: dict[
            Path, float
        ] = {}  # Track encode duration per video
        self.start_time = time.time()

    def warn(self, message: str) -> None:
        CONSOLE.print(f"[warn] {message}", style="yellow")

    def save_cache(self) -> None:
        with SAVE_LOCK:
            self.hash_cache.save()

    def format_optimized_cell(self, optimized_size: int, original_size: int) -> str:
        saved = original_size - optimized_size
        if saved <= 0:
            return "no gain"
        optimized_text = self.human_bytes(optimized_size)
        pct_text = self.savings_pct(original_size, saved)
        return f"{optimized_text} ({pct_text})"

    def detect_mime(self, path: Path) -> str:
        try:
            return magic.from_file(str(path), mime=True)
        except (FileNotFoundError, OSError, magic.MagicException):
            return "unknown"

    def detect_kind(self, path: Path) -> str | None:
        mime = self.detect_mime(path)
        if mime.startswith("image/"):
            return "image"
        if mime.startswith("video/") or mime in VIDEO_MIME_ALIASES:
            return "video"
        return None

    def path_in_cache(self, path: Path) -> bool:
        try:
            path.relative_to(self.cache_dir)
            return True
        except ValueError:
            return False

    def discover_media(self) -> None:
        if self.input_path.is_file():
            kind = self.detect_kind(self.input_path)
            self.media_files = [self.input_path] if kind is not None else []
        else:
            self.media_files = sorted(
                path
                for path in self.target_dir.rglob("*")
                if path.is_file()
                and not self.path_in_cache(path)
                and self.detect_kind(path) is not None
            )
        if not self.media_files:
            CONSOLE.print(
                f"No supported image/video files found under '{self.input_path}'."
            )
            raise SystemExit(0)
        if self.input_path.is_file():
            CONSOLE.print(f"Found 1 media file: '{self.input_path}'.")
        else:
            CONSOLE.print(
                f"Found {len(self.media_files)} media file(s) under '{self.target_dir}'."
            )

    def file_hash(self, path: Path) -> str:
        digest = hashlib.sha256()
        with path.open("rb") as handle:
            for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                digest.update(chunk)
        return digest.hexdigest()

    def build_type_key(self, kind: str, label: str) -> str:
        return f"{kind}:{label.lower()}"

    def split_type_key(self, type_key: str) -> tuple[str, str]:
        if ":" in type_key:
            kind, label = type_key.split(":", 1)
            if kind in {"image", "video"}:
                return kind, label or "unknown"
        if type_key and type_key != "unknown":
            return "image", type_key.lower()
        return "unknown", "unknown"

    def display_type(self, type_key: str) -> str:
        _kind, label = self.split_type_key(type_key)
        return label

    def skip_action(self, entry: CacheEntry) -> str:
        if entry.done:
            return "done"
        kind, label = self.split_type_key(entry.file_type)
        if kind == "image" and label == TARGET_IMAGE_TYPE:
            return "skip webp"
        if kind == "video" and label == TARGET_VIDEO_TYPE:
            return "skip av1"
        return "skipped"

    def is_already_optimized(self, entry: CacheEntry) -> bool:
        kind, label = self.split_type_key(entry.file_type)
        return (
            entry.done
            or (kind == "image" and label == TARGET_IMAGE_TYPE)
            or (kind == "video" and label == TARGET_VIDEO_TYPE)
        )

    def video_codec(self, path: Path) -> str:
        result = subprocess.run(
            [
                "ffprobe",
                "-v",
                "error",
                "-select_streams",
                "v:0",
                "-show_entries",
                "stream=codec_name",
                "-of",
                "default=noprint_wrappers=1:nokey=1",
                str(path),
            ],
            check=False,
            capture_output=True,
            text=True,
        )
        if result.returncode != 0:
            if self.debug_enabled:
                stderr = result.stderr.strip()
                if stderr:
                    self.warn(f"ffprobe failed: {path}: {stderr}")
            return "unknown"
        for line in result.stdout.splitlines():
            codec = line.strip().lower()
            if codec:
                return codec
        return "unknown"

    def video_duration_seconds(self, path: Path) -> float | None:
        result = subprocess.run(
            [
                "ffprobe",
                "-v",
                "error",
                "-show_entries",
                "format=duration",
                "-of",
                "default=noprint_wrappers=1:nokey=1",
                str(path),
            ],
            check=False,
            capture_output=True,
            text=True,
        )
        if result.returncode != 0:
            if self.debug_enabled:
                self.warn(f"ffprobe duration failed: {path}")
            return None
        try:
            duration = float(result.stdout.strip())
        except ValueError:
            if self.debug_enabled:
                self.warn(f"failed to parse duration: {path}")
            return None
        return duration if duration > 0 else None

    def extract_segment(
        self, path: Path, start_seconds: float, duration: int = SEGMENT_DURATION
    ) -> Path | None:
        """Extract a segment from video via ffmpeg.

        Returns path to temp segment file or None on error.
        """
        fd, tmp_path_str = tempfile.mkstemp(
            prefix=".seg_",
            suffix=".mp4",
            dir=self.cache_dir,
        )
        os.close(fd)
        tmp_path = Path(tmp_path_str)
        try:
            result = subprocess.run(
                [
                    "ffmpeg",
                    "-ss",
                    str(start_seconds),
                    "-i",
                    str(path),
                    "-t",
                    str(duration),
                    "-c",
                    "copy",
                    "-y",
                    str(tmp_path),
                ],
                check=False,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            if result.returncode == 0 and tmp_path.exists():
                return tmp_path
        except OSError as e:
            if self.debug_enabled:
                self.warn(f"extract_segment failed: {path}: {e}")
        finally:
            pass  # Keep temp file; caller responsible for cleanup
        tmp_path.unlink(missing_ok=True)
        return None

    def get_crf_for_video(self, path: Path) -> int:
        """Detect video resolution; return CRF 26 for 4K, 30 for lower."""
        result = subprocess.run(
            [
                "ffprobe",
                "-v",
                "error",
                "-select_streams",
                "v:0",
                "-show_entries",
                "stream=width,height",
                "-of",
                "default=noprint_wrappers=1:nokey=1",
                str(path),
            ],
            check=False,
            capture_output=True,
            text=True,
        )
        if result.returncode != 0:
            return 30  # Default to 30 if probe fails

        lines = result.stdout.strip().split("\n")
        try:
            width = int(lines[0].strip())
            height = int(lines[1].strip()) if len(lines) > 1 else 0
            if width >= 2160 or height >= 2160:
                return 26
        except (ValueError, IndexError):
            pass
        return 30

    def encode_segment_only(
        self,
        segment_path: Path,
        crf: int,
        progress_callback: Callable[[HandBrakeProgress, float], None] | None = None,
    ) -> int | None:
        """Encode single segment to MP4 AV1; return output size or None on error."""
        fd, tmp_out = tempfile.mkstemp(
            prefix=".enc_seg_",
            suffix=".mp4",
            dir=self.cache_dir,
        )
        os.close(fd)
        tmp_out_path = Path(tmp_out)
        try:
            command = [
                "HandBrakeCLI",
                "-i",
                str(segment_path),
                "-o",
                str(tmp_out_path),
                "--format",
                "av_mp4",
                "--encoder",
                "svt_av1",
                "--encoder-preset",
                VIDEO_PRESET,
                "--encoder-tune",
                VIDEO_TUNE,
                "--quality",
                str(crf),
                "--multi-pass",
                "--vfr",
                "--audio-copy-mask",
                VIDEO_AUDIO_COPY_MASK,
                "--audio-fallback",
                VIDEO_AUDIO_FALLBACK,
                "-E",
                VIDEO_AUDIO_ENCODERS,
                "-B",
                VIDEO_AUDIO_BITRATES,
                "-6",
                VIDEO_AUDIO_MIXDOWN,
            ]

            if progress_callback is not None:
                command.insert(1, "--json")
                returncode = self.run_video_command(
                    command,
                    progress_callback=progress_callback,
                )
            else:
                result = subprocess.run(
                    command,
                    check=False,
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                )
                returncode = result.returncode
            if returncode == 0 and tmp_out_path.exists():
                return tmp_out_path.stat().st_size
        except OSError as e:
            if self.debug_enabled:
                self.warn(f"encode_segment_only failed: {segment_path}: {e}")
        finally:
            tmp_out_path.unlink(missing_ok=True)
        return None

    def estimate_video_expansion(
        self,
        path: Path,
        progress_callback: Callable[[VideoSampleProgress], None] | None = None,
    ) -> VideoSampleEstimate | None:
        """Estimate compression by encoding 3 random segments."""
        duration = self.video_duration_seconds(path)
        if duration is None:
            return None

        if duration <= SEGMENT_DURATION:
            crf = self.get_crf_for_video(path)

            def whole_video_progress(update: HandBrakeProgress, elapsed: float) -> None:
                if progress_callback is not None:
                    progress_callback(
                        VideoSampleProgress(
                            progress=update,
                            elapsed=elapsed,
                            sample_index=1,
                            sample_count=1,
                            sample_duration=duration,
                        )
                    )

            encoded_size = self.encode_segment_only(
                path,
                crf,
                progress_callback=whole_video_progress if progress_callback else None,
            )
            if encoded_size is None:
                return None
            original_size = path.stat().st_size
            return VideoSampleEstimate([encoded_size], [original_size])

        crf = self.get_crf_for_video(path)
        segment_sizes = []
        original_sizes = []

        for sample_index, pos in enumerate(SEGMENT_POSITIONS, start=1):
            start_sec = pos * duration
            start_sec = min(start_sec, duration - SEGMENT_DURATION)

            segment = self.extract_segment(path, start_sec)
            if segment is None:
                if self.debug_enabled:
                    self.warn(f"extract segment failed: {path} at {start_sec}s")
                return None

            try:
                original_seg_size = segment.stat().st_size

                def segment_progress(
                    update: HandBrakeProgress,
                    elapsed: float,
                    current_sample_index: int = sample_index,
                    current_sample_count: int = len(SEGMENT_POSITIONS),
                ) -> None:
                    if progress_callback is not None:
                        progress_callback(
                            VideoSampleProgress(
                                progress=update,
                                elapsed=elapsed,
                                sample_index=current_sample_index,
                                sample_count=current_sample_count,
                                sample_duration=float(SEGMENT_DURATION),
                            )
                        )

                encoded_size = self.encode_segment_only(
                    segment,
                    crf,
                    progress_callback=segment_progress if progress_callback else None,
                )
                if encoded_size is None:
                    if self.debug_enabled:
                        self.warn(f"encode segment failed: {segment}")
                    return None

                segment_sizes.append(encoded_size)
                original_sizes.append(original_seg_size)
            finally:
                segment.unlink(missing_ok=True)

        return VideoSampleEstimate(segment_sizes, original_sizes)

    def file_type(self, path: Path) -> str:
        mime = self.detect_mime(path)
        if mime.startswith("image/"):
            return self.build_type_key("image", mime.removeprefix("image/"))
        if mime.startswith("video/") or mime in VIDEO_MIME_ALIASES:
            codec = self.video_codec(path)
            if codec != "unknown":
                return self.build_type_key("video", codec)
            label = mime.removeprefix("video/") if mime.startswith("video/") else "mp4"
            return self.build_type_key("video", label)
        return "unknown"

    def cache_output_path(self, sha256: str, file_type: str) -> Path | None:
        kind, _label = self.split_type_key(file_type)
        if kind == "image":
            return self.cache_dir / f"{sha256}.webp"
        if kind == "video":
            return self.cache_dir / f"{sha256}.mp4"
        return None

    def compute_missing_hashes(
        self,
        missing: list[Path],
    ) -> dict[Path, CacheEntry]:
        results: dict[Path, CacheEntry] = {}
        if not missing:
            return results
        progress_results: dict[Path, CacheEntry | None] = {}
        self.warn(f"hash misses={len(missing)}")
        self.run_progress(
            "Hashing",
            missing,
            self.hash_worker,
            None,
            results=progress_results,
            description_suffix="sha256",
        )
        for path, entry in progress_results.items():
            if entry is not None:
                results[path] = entry
        computed = len(results)
        failed = len(missing) - computed
        suffix = f", {failed} failed (skipped)" if failed else ""
        CONSOLE.print(f"sha256: {computed} computed{suffix}.")
        return results

    def hash_worker(self, path: Path, _state: object) -> tuple[Path, CacheEntry | None]:
        if STOP_EVENT.is_set():
            return path, None
        try:
            stat = path.stat()
            entry = CacheEntry(
                mtime_ns=stat.st_mtime_ns,
                size=stat.st_size,
                sha256=self.file_hash(path),
                file_type=self.file_type(path),
                done=False,
            )
            return path, entry
        except OSError as exc:
            self.warn(f"hash failed: {path}: {exc}")
            return path, None

    def cache_hashes(self) -> dict[Path, CacheEntry]:
        entries: dict[Path, CacheEntry] = {}
        missing: list[Path] = []

        for path in self.media_files:
            entry = self.hash_cache.lookup(path)
            if entry is None:
                missing.append(path)
                continue
            entries[path] = entry
            self.hash_hits += 1

        CONSOLE.print(f"Hash cache: {self.hash_hits} hit(s), {len(missing)} miss(es).")

        computed = self.compute_missing_hashes(missing)
        for path, entry in computed.items():
            entries[path] = entry
            self.hash_cache.update(path, entry)
        return entries

    def build_image_command(self, source: Path, output: Path) -> list[str]:
        return [
            "convert",
            str(source),
            "-quality",
            str(IMAGE_QUALITY),
            f"webp:{output}",
        ]

    def build_video_command(self, source: Path, output: Path) -> list[str]:
        return [
            "HandBrakeCLI",
            "--json",
            "-i",
            str(source),
            "-o",
            str(output),
            "--format",
            "av_mp4",
            "--markers",
            "--align-av",
            "--keep-metadata",
            "--disable-hw-decoding",
            "--encoder",
            "svt_av1",
            "--encoder-preset",
            VIDEO_PRESET,
            "--encoder-tune",
            VIDEO_TUNE,
            "--quality",
            str(VIDEO_QUALITY),
            "--multi-pass",
            "--vfr",
            "--hdr-dynamic-metadata",
            "all",
            "--audio-copy-mask",
            VIDEO_AUDIO_COPY_MASK,
            "--audio-fallback",
            VIDEO_AUDIO_FALLBACK,
            "--first-audio",
            "-E",
            VIDEO_AUDIO_ENCODERS,
            "-B",
            VIDEO_AUDIO_BITRATES,
            "-6",
            VIDEO_AUDIO_MIXDOWN,
            "-R",
            VIDEO_AUDIO_SAMPLERATES,
            "--keep-aname",
            "--automatic-naming-behaviour",
            "unnamed",
            "--crop-mode",
            "auto",
            "-X",
            str(VIDEO_MAX_WIDTH),
            "-Y",
            str(VIDEO_MAX_HEIGHT),
            "--auto-anamorphic",
            "--keep-display-aspect",
            "--modulus",
            "2",
            "--color-range",
            "limited",
            "--comb-detect",
            "--decomb",
            "-s",
            "scan",
            "--keep-subname",
            "--subtitle-forced",
            "--subtitle-burned",
        ]

    def verify_image_output(self, path: Path, warn: bool = True) -> bool:
        try:
            with Image.open(path) as img:
                img.verify()
            with Image.open(path) as img:
                _ = img.load()
        except (OSError, UnidentifiedImageError) as exc:
            if warn:
                self.warn(f"invalid webp: {path}: {exc}")
            return False
        if self.file_type(path) != self.build_type_key("image", TARGET_IMAGE_TYPE):
            if warn:
                self.warn(f"invalid image output: {path}: not webp")
            return False
        return True

    def verify_video_output(self, path: Path, warn: bool = True) -> bool:
        if self.file_type(path) == self.build_type_key("video", TARGET_VIDEO_TYPE):
            return True
        if warn:
            self.warn(f"invalid video output: {path}: not av1")
        return False

    def verify_target_output(self, path: Path, kind: str, warn: bool = True) -> bool:
        if kind == "image":
            return self.verify_image_output(path, warn=warn)
        if kind == "video":
            return self.verify_video_output(path, warn=warn)
        return False

    def has_cached_output(self, entry: CacheEntry) -> bool:
        cached = self.cache_output_path(entry.sha256, entry.file_type)
        if cached is None or not cached.exists():
            return False
        kind, _label = self.split_type_key(entry.file_type)
        return self.verify_target_output(cached, kind, warn=False)

    def parse_handbrake_progress_block(
        self,
        block: str,
    ) -> HandBrakeProgress | None:
        try:
            data = json.loads(block)
        except (json.JSONDecodeError, TypeError, ValueError):
            return None
        if data.get("State") != "WORKING":
            return None
        working = data.get("Working")
        if not isinstance(working, dict):
            return None
        try:
            fraction = float(working.get("Progress", 0.0))
        except (TypeError, ValueError):
            fraction = 0.0
        try:
            eta_raw = int(working.get("ETASeconds", -1))
        except (TypeError, ValueError):
            eta_raw = -1
        try:
            current_pass = int(working.get("Pass", 1))
        except (TypeError, ValueError):
            current_pass = 1
        try:
            pass_count = int(working.get("PassCount", 1))
        except (TypeError, ValueError):
            pass_count = 1
        return HandBrakeProgress(
            fraction=min(max(fraction, 0.0), 1.0),
            eta_seconds=eta_raw if eta_raw >= 0 else None,
            current_pass=current_pass,
            pass_count=pass_count,
        )

    def iter_handbrake_progress(
        self,
        lines: Iterable[str],
    ) -> Iterable[HandBrakeProgress]:
        block_lines: list[str] = []
        brace_depth = 0
        collecting = False
        for raw_line in lines:
            line = raw_line.rstrip("\n")
            if not collecting:
                if not line.startswith("Progress:"):
                    continue
                first_line = line.removeprefix("Progress:").strip()
                if not first_line:
                    continue
                block_lines = [first_line]
                brace_depth = first_line.count("{") - first_line.count("}")
                collecting = True
            else:
                block_lines.append(line)
                brace_depth += line.count("{") - line.count("}")
            if collecting and brace_depth <= 0:
                progress = self.parse_handbrake_progress_block("\n".join(block_lines))
                if progress is not None:
                    yield progress
                block_lines = []
                brace_depth = 0
                collecting = False

    def estimate_current_video_eta(
        self,
        progress: HandBrakeProgress,
        elapsed: float,
    ) -> float | None:
        if progress.eta_seconds is not None and progress.eta_seconds > 0:
            return float(progress.eta_seconds)
        if progress.fraction <= 0:
            return None
        if progress.fraction >= 1.0:
            return 0.0
        total_estimated = elapsed / progress.fraction
        return max(total_estimated - elapsed, 0.0)

    def estimate_sample_queue_eta(
        self,
        progress: HandBrakeProgress,
        elapsed: float,
        sample_index: int,
        sample_count: int,
    ) -> float | None:
        current_eta = self.estimate_current_video_eta(progress, elapsed)
        if current_eta is None:
            return None
        remaining_after_current = max(sample_count - sample_index, 0)
        current_total_estimate = elapsed + current_eta
        return current_eta + (remaining_after_current * current_total_estimate)

    def estimate_video_queue_eta(
        self,
        current_eta_seconds: int | None,
        current_fraction: float | None,
        current_duration: float | None,
        current_elapsed: float,
        remaining_durations: Iterable[float | None],
        completed_timings: list[tuple[float, float]],
    ) -> float | None:
        ratio_samples = [
            wall_time / duration
            for duration, wall_time in completed_timings
            if duration > 0 and wall_time > 0
        ]
        current_eta = (
            float(current_eta_seconds)
            if current_eta_seconds is not None and current_eta_seconds > 0
            else None
        )
        if current_duration is not None and current_duration > 0:
            if current_eta is not None:
                ratio_samples.append((current_elapsed + current_eta) / current_duration)
            elif current_fraction is not None and 0 < current_fraction < 1.0:
                total_wall_estimate = current_elapsed / current_fraction
                ratio_samples.append(total_wall_estimate / current_duration)
                current_eta = max(total_wall_estimate - current_elapsed, 0.0)
        avg_ratio = sum(ratio_samples) / len(ratio_samples) if ratio_samples else None
        remaining_total = sum(
            duration
            for duration in remaining_durations
            if duration is not None and duration > 0
        )
        remaining_eta = remaining_total * avg_ratio if avg_ratio is not None else None
        if current_eta is None:
            return remaining_eta
        if remaining_eta is None:
            return current_eta
        return current_eta + remaining_eta

    def run_video_command(
        self,
        command: list[str],
        progress_callback: Callable[[HandBrakeProgress, float], None] | None = None,
    ) -> int:
        proc = subprocess.Popen(
            command,
            stdout=subprocess.PIPE,
            stderr=None if self.debug_enabled else subprocess.DEVNULL,
            text=True,
            bufsize=1,
        )
        start_time = time.time()
        if proc.stdout is not None:
            for progress in self.iter_handbrake_progress(proc.stdout):
                if progress_callback is not None:
                    progress_callback(progress, time.time() - start_time)
        return proc.wait()

    def compute_video_durations(
        self,
        videos: list[Path],
    ) -> dict[Path, float | None]:
        if not videos:
            return {}
        durations: dict[Path, float | None] = {}
        max_workers = min(self.jobs, len(videos))
        with ThreadPoolExecutor(max_workers=max_workers) as executor:
            futures = {
                executor.submit(self.video_duration_seconds, path): path
                for path in videos
            }
            for future in as_completed(futures):
                durations[futures[future]] = future.result()
        return durations

    def convert_one(
        self,
        path: Path,
        entry: CacheEntry,
        progress_callback: Callable[[HandBrakeProgress, float], None] | None = None,
        estimate_progress_callback: Callable[[VideoSampleProgress], None] | None = None,
    ) -> bool:
        if STOP_EVENT.is_set():
            return False
        cached = self.cache_output_path(entry.sha256, entry.file_type)
        if cached is None:
            return False

        kind, _label = self.split_type_key(entry.file_type)
        if cached.exists() and self.verify_target_output(cached, kind, warn=False):
            return True

        if kind == "video" and not entry.video_estimate_json:
            if self.debug_enabled:
                self.warn(f"Estimating: {path}")
            estimate = self.estimate_video_expansion(
                path,
                progress_callback=estimate_progress_callback,
            )
            if estimate is not None:
                if self.debug_enabled:
                    self.warn(
                        f"  Estimate: ratio={estimate.avg_ratio():.2f}, "
                        f"savings={estimate.avg_savings_pct():.1f}%, "
                        + f"will_expand={estimate.will_expand()}"
                    )
                entry.video_estimate_json = self.hash_cache.estimate_to_json(estimate)
                if estimate.will_expand() and not self.force_expand:
                    if self.debug_enabled:
                        self.warn(
                            f"Skipping expansion: {path} ({estimate.avg_savings_pct():.1f}%)"
                        )
                    return True
                if self.estimate_only:
                    if self.debug_enabled:
                        self.warn(
                            f"Estimate only: {path} ({estimate.avg_savings_pct():.1f}% savings)"
                        )
                    return True
            elif self.debug_enabled:
                self.warn(f"  Estimate failed for: {path}")

        if self.estimate_only:
            return True

        if kind == "video" and entry.video_estimate_json and not self.force_expand:
            estimate = self.hash_cache.json_to_estimate(entry.video_estimate_json)
            if estimate is not None and estimate.will_expand():
                if self.debug_enabled:
                    self.warn(
                        f"Skipping cached expansion: {path} ({estimate.avg_savings_pct():.1f}%)"
                    )
                return True

        fd, tmp_name = tempfile.mkstemp(
            prefix=cached.stem + ".",
            suffix=cached.suffix,
            dir=self.cache_dir,
        )
        os.close(fd)
        tmp_output = Path(tmp_name)
        tmp_output.unlink(missing_ok=True)
        try:
            command = (
                self.build_image_command(path, tmp_output)
                if kind == "image"
                else self.build_video_command(path, tmp_output)
            )
            start_time = time.time()
            if kind == "video":
                returncode = self.run_video_command(
                    command,
                    progress_callback=progress_callback,
                )
            else:
                result = subprocess.run(
                    command,
                    check=False,
                    stdout=None if self.debug_enabled else subprocess.DEVNULL,
                    stderr=None if self.debug_enabled else subprocess.DEVNULL,
                )
                returncode = result.returncode
            elapsed = time.time() - start_time
            if kind == "video":
                self.video_encode_times[path] = elapsed
            if returncode != 0:
                return False
            if not tmp_output.exists() or not self.verify_target_output(
                tmp_output, kind
            ):
                return False
            _ = tmp_output.replace(cached)
            return True
        finally:
            tmp_output.unlink(missing_ok=True)

    def convert_files(self, entries: dict[Path, CacheEntry]) -> None:
        missing = [
            path
            for path in self.media_files
            if path in entries
            and not self.is_already_optimized(entries[path])
            and not self.has_cached_output(entries[path])
        ]

        self.conversion_hits = len(entries) - len(missing)
        CONSOLE.print(
            f"Conversion cache: {self.conversion_hits} hit(s), {len(missing)} miss(es)."
        )
        if self.debug_enabled and missing:
            for path in missing:
                kind = self.split_type_key(entries[path].file_type)[0]
                self.warn(f"Missing {kind}: {path}")
        if not missing:
            return
        convert_results: dict[Path, bool] = {}
        self.warn(f"conversion misses={len(missing)}")

        # Separate videos and images
        videos = [
            path
            for path in missing
            if self.split_type_key(entries[path].file_type)[0] == "video"
        ]
        images = [
            path
            for path in missing
            if self.split_type_key(entries[path].file_type)[0] == "image"
        ]

        # Process images in parallel
        if images:
            self.run_progress(
                "Converting",
                images,
                self.convert_worker,
                entries,
                results=convert_results,
                description_suffix="image(s)",
            )

        # Process videos sequentially (HandBrake uses all cores per instance)
        if videos:
            self.convert_videos_with_progress(videos, entries, convert_results)
        failed = 0
        for path, ok in convert_results.items():
            if not ok:
                failed += 1
                self.errors += 1
                self.warn(f"convert failed: {path}")
        CONSOLE.print("Conversion complete.")
        if failed:
            CONSOLE.print(f"Conversion failures: {failed}")

    def convert_videos_with_progress(
        self,
        videos: list[Path],
        entries: dict[Path, CacheEntry],
        results: dict[Path, bool],
    ) -> None:
        total = len(videos)
        if total == 0:
            return
        display_root = (
            self.input_path.parent if self.input_path.is_file() else self.target_dir
        )
        durations = self.compute_video_durations(videos)
        completed_timings: list[tuple[float, float]] = []
        progress = Progress(
            SpinnerColumn(),
            TextColumn("{task.description}"),
            BarColumn(bar_width=None),
            TextColumn("{task.fields[status]}"),
            TextColumn("ETA {task.fields[eta]}"),
            TimeElapsedColumn(),
            console=CONSOLE,
            transient=False,
            refresh_per_second=12,
        )
        queue_task = progress.add_task(
            "Converting video(s)",
            total=float(total),
            completed=0,
            status=f"0/{total}",
            eta="--",
        )
        current_task = progress.add_task(
            "Encoding —",
            total=1.0,
            completed=0,
            status="queued",
            eta="--",
        )
        with progress:
            for index, path in enumerate(videos):
                rel_path = self.truncate_path(path.relative_to(display_root), 48)
                current_duration = durations[path]
                remaining_durations = [
                    durations[other] for other in videos[index + 1:]
                ]
                progress.update(
                    current_task,
                    description=f"Encoding {rel_path}",
                    completed=0.0,
                    status="preparing",
                    eta="--",
                )
                debug_bucket = -1
                debug_pass = -1
                debug_sample_bucket = -1
                debug_sample_index = -1

                def on_estimate_progress(
                    sample: VideoSampleProgress,
                    current_rel_path: str = rel_path,
                    current_name: str = path.name,
                ) -> None:
                    nonlocal debug_sample_bucket, debug_sample_index
                    sample_eta = self.estimate_current_video_eta(
                        sample.progress,
                        sample.elapsed,
                    )
                    sample_queue_eta = self.estimate_sample_queue_eta(
                        sample.progress,
                        sample.elapsed,
                        sample.sample_index,
                        sample.sample_count,
                    )
                    progress.update(
                        queue_task,
                        description=f"Estimating {current_rel_path}",
                        total=float(sample.sample_count),
                        completed=(sample.sample_index - 1) + sample.progress.fraction,
                        status=f"{sample.sample_index}/{sample.sample_count}",
                        eta=(
                            self._format_duration(sample_queue_eta)
                            if sample_queue_eta is not None
                            else "--"
                        ),
                    )
                    progress.update(
                        current_task,
                        description=(
                            f"Sample {sample.sample_index}/{sample.sample_count} "
                            f"{current_rel_path}"
                        ),
                        total=1.0,
                        completed=sample.progress.fraction,
                        status=(
                            f"{sample.progress.fraction * 100:5.1f}% "
                            f"pass {sample.progress.current_pass}/"
                            f"{sample.progress.pass_count}"
                        ),
                        eta=(
                            self._format_duration(sample_eta)
                            if sample_eta is not None
                            else "--"
                        ),
                    )
                    if self.debug_enabled:
                        bucket = int(sample.progress.fraction * 10)
                        if (
                            bucket != debug_sample_bucket
                            or sample.sample_index != debug_sample_index
                        ):
                            debug_sample_bucket = bucket
                            debug_sample_index = sample.sample_index
                            self.warn(
                                f"sample {current_name} {sample.sample_index}/"
                                + f"{sample.sample_count}: "
                                + f"{sample.progress.fraction * 100:5.1f}% "
                                + f"pass {sample.progress.current_pass}/"
                                + f"{sample.progress.pass_count} eta="
                                + f"{self._format_duration(sample_eta) if sample_eta is not None else '--'}"
                            )

                def on_progress(
                    update: HandBrakeProgress,
                    elapsed: float,
                    current_index: int = index,
                    current_media_duration: float | None = current_duration,
                    current_remaining_durations: list[
                        float | None
                    ] = remaining_durations,
                    current_name: str = path.name,
                    current_rel_path: str = rel_path,
                ) -> None:
                    nonlocal debug_bucket, debug_pass
                    # Snapshot loop-local values with default args.
                    # Keep completed_timings live by reference so queue ETA
                    # improves after each finished encode.
                    current_eta = self.estimate_current_video_eta(update, elapsed)
                    queue_eta = self.estimate_video_queue_eta(
                        update.eta_seconds,
                        update.fraction,
                        current_media_duration,
                        elapsed,
                        current_remaining_durations,
                        completed_timings,
                    )
                    progress.update(
                        queue_task,
                        description="Converting video(s)",
                        total=float(total),
                        completed=current_index + update.fraction,
                        status=f"{current_index}/{total}",
                        eta=(
                            self._format_duration(queue_eta)
                            if queue_eta is not None
                            else "--"
                        ),
                    )
                    progress.update(
                        current_task,
                        description=f"Encoding {current_rel_path}",
                        total=1.0,
                        completed=update.fraction,
                        status=(
                            f"{update.fraction * 100:5.1f}% "
                            f"pass {update.current_pass}/{update.pass_count}"
                        ),
                        eta=(
                            self._format_duration(current_eta)
                            if current_eta is not None
                            else "--"
                        ),
                    )
                    if self.debug_enabled:
                        bucket = int(update.fraction * 10)
                        if bucket != debug_bucket or update.current_pass != debug_pass:
                            debug_bucket = bucket
                            debug_pass = update.current_pass
                            self.warn(
                                f"hb {current_name}: {update.fraction * 100:5.1f}% "
                                f"pass {update.current_pass}/{update.pass_count} "
                                + f"eta={self._format_duration(current_eta) if current_eta is not None else '--'}"
                            )

                ok = self.convert_one(
                    path,
                    entries[path],
                    progress_callback=on_progress,
                    estimate_progress_callback=on_estimate_progress,
                )
                results[path] = ok
                elapsed = self.video_encode_times.get(path, 0.0)
                if current_duration is not None and elapsed > 0:
                    completed_timings.append((current_duration, elapsed))
                remaining_eta = self.estimate_video_queue_eta(
                    None,
                    None,
                    None,
                    0.0,
                    remaining_durations,
                    completed_timings,
                )
                progress.update(
                    queue_task,
                    completed=float(index + 1),
                    status=f"{index + 1}/{total}",
                    eta=(
                        self._format_duration(remaining_eta)
                        if remaining_eta is not None
                        else "--"
                    ),
                )
                progress.update(
                    current_task,
                    completed=1.0 if ok else 0.0,
                    status=(
                        "done"
                        if ok and self.has_cached_output(entries[path])
                        else "skipped"
                        if ok
                        else "failed"
                    ),
                    eta="0.0s" if ok else "--",
                )

    def convert_worker(
        self,
        path: Path,
        entries: dict[Path, CacheEntry],
    ) -> tuple[Path, bool]:
        return path, self.convert_one(path, entries[path])

    def apply_one(self, path: Path, entry: CacheEntry) -> ApplyResult:
        cached = self.cache_output_path(entry.sha256, entry.file_type)
        if cached is None or not cached.exists():
            return ApplyResult("failed")

        kind, _label = self.split_type_key(entry.file_type)
        if not self.verify_target_output(cached, kind):
            return ApplyResult("failed")

        original_stat = path.stat()
        fd, tmp_name = tempfile.mkstemp(
            prefix=".img_savings_",
            suffix=cached.suffix or ".tmp",
            dir=path.parent,
        )
        os.close(fd)
        tmp_path = Path(tmp_name)
        try:
            _ = shutil.copyfile(cached, tmp_path)
            os.chmod(tmp_path, original_stat.st_mode)
            _ = tmp_path.replace(path)
            os.utime(path, ns=(original_stat.st_atime_ns, original_stat.st_mtime_ns))
            final_stat = path.stat()
            return ApplyResult(
                "replaced",
                CacheEntry(
                    mtime_ns=final_stat.st_mtime_ns,
                    size=final_stat.st_size,
                    sha256=self.file_hash(path),
                    file_type=self.file_type(path),
                    done=True,
                ),
            )
        except OSError as exc:
            self.warn(f"apply failed: {path}: {exc}")
            return ApplyResult("failed")
        finally:
            tmp_path.unlink(missing_ok=True)

    def apply_worker(
        self,
        path: Path,
        entries: dict[Path, CacheEntry],
    ) -> tuple[Path, ApplyResult]:
        status = self.apply_one(path, entries[path])
        return path, status

    def human_bytes(self, size: int) -> str:
        if size >= 1073741824:
            return f"{size / 1073741824:8.2f} GB"
        if size >= 1048576:
            return f"{size / 1048576:8.2f} MB"
        if size >= 1024:
            return f"{size / 1024:8.2f} KB"
        return f"{size:8d} B"

    def _format_duration(self, seconds: float) -> str:
        """Format duration in human-readable format."""
        if seconds < 60:
            return f"{seconds:.1f}s"
        if seconds < 3600:
            minutes = seconds / 60
            return f"{minutes:.1f}m"
        hours = seconds / 3600
        return f"{hours:.1f}h"

    def savings_pct(self, original: int, saved: int) -> str:
        if original == 0 or saved <= 0:
            return "—"
        return f"{(saved / original) * 100:.1f}%"

    def optimized_cell(self, optimized_size: int, original_size: int) -> str:
        saved = original_size - optimized_size
        if saved <= 0:
            return "no gain"
        return self.format_optimized_cell(optimized_size, original_size)

    def collect_results(self, entries: dict[Path, CacheEntry]) -> list[FileResult]:
        results: list[FileResult] = []
        to_apply: list[Path] = []

        for path in self.media_files:
            entry = entries.get(path)
            if entry is None:
                self.errors += 1
                self.warn(f"missing hash: {path}")
                continue

            original_size = path.stat().st_size
            cached = self.cache_output_path(entry.sha256, entry.file_type)
            kind, _label = self.split_type_key(entry.file_type)

            # Load estimate from cache (computed during convert_one)
            estimate = None
            if kind == "video" and entry.video_estimate_json:
                estimate = self.hash_cache.json_to_estimate(entry.video_estimate_json)
                if self.debug_enabled and estimate is not None:
                    self.warn(
                        f"Loaded estimate for {path.name}: "
                        + f"{estimate.avg_savings_pct():.1f}% savings"
                    )

            # Check if expansion; mark for skip if so
            if (
                estimate is not None
                and estimate.will_expand()
                and not self.force_expand
            ):
                # Mark skipped expansion
                display_root = (
                    self.input_path.parent
                    if self.input_path.is_file()
                    else self.target_dir
                )
                # Calculate estimated optimized size from ratio
                est_optimized_size = int(original_size * estimate.avg_ratio())
                est_delta = est_optimized_size - original_size
                est_delta_str = self.human_bytes(abs(est_delta)).strip()
                action_str = f"skip expand (est. +{est_delta_str} / {estimate.avg_savings_pct():.1f}%)"
                results.append(
                    FileResult(
                        path=path,
                        rel_path=self.truncate_path(path.relative_to(display_root), 72),
                        file_type=entry.file_type,
                        original_size=original_size,
                        optimized_size=original_size,  # No optimization
                        action=action_str,
                        estimate=estimate,
                    )
                )
                self.skipped_expansion += 1
                continue

            # Normal flow
            if self.is_already_optimized(entry):
                optimized_size = original_size
            elif cached is not None and cached.exists():
                optimized_size = min(cached.stat().st_size, original_size)
            else:
                optimized_size = original_size

            action_desc = ""
            if estimate is not None:
                # Show size delta + percent
                est_optimized_size = int(original_size * estimate.avg_ratio())
                est_saved = original_size - est_optimized_size
                est_saved_str = self.human_bytes(est_saved).strip()
                action_desc = (
                    f"est. -{est_saved_str} ({estimate.avg_savings_pct():.1f}%)"
                )
            elif kind == "image":
                # Images don't get estimates, show that they'll be processed
                action_desc = "will convert to webp"

            if (
                self.apply
                and not self.is_already_optimized(entry)
                and cached is not None
                and cached.exists()
                and optimized_size < original_size
            ):
                to_apply.append(path)

            display_root = (
                self.input_path.parent if self.input_path.is_file() else self.target_dir
            )
            results.append(
                FileResult(
                    path=path,
                    rel_path=self.truncate_path(path.relative_to(display_root), 72),
                    file_type=entry.file_type,
                    original_size=original_size,
                    optimized_size=optimized_size,
                    action=action_desc,
                    estimate=estimate,
                )
            )

        apply_results: dict[Path, ApplyResult] = {}
        if self.apply and to_apply:
            self.run_progress(
                "Applying",
                to_apply,
                self.apply_worker,
                entries,
                results=apply_results,
                description_suffix="replacement(s)",
            )
            for path, outcome in apply_results.items():
                if outcome.status == "replaced":
                    self.applied += 1
                    if outcome.entry is not None:
                        entries[path] = outcome.entry
                        self.hash_cache.update(path, outcome.entry)
                else:
                    self.errors += 1

        for result in results:
            entry = entries[result.path]
            saved = result.original_size - result.optimized_size
            outcome = apply_results.get(result.path)
            if self.apply:
                if outcome is not None and outcome.status == "replaced":
                    result.action = "✓ replaced"
                elif self.is_already_optimized(entry):
                    result.action = self.skip_action(entry)
                elif saved > 0:
                    result.action = "✗ failed"
                else:
                    result.action = "skipped"
                    self.skipped_no_gain += 1
            else:
                if self.is_already_optimized(entry):
                    result.action = self.skip_action(entry)
                elif (
                    not result.action
                ):  # Only overwrite if no action set (e.g., images)
                    result.action = "would replace" if saved > 0 else "no gain"
        return results

    def render_results(self, results: list[FileResult]) -> None:
        table = Table(show_header=True, header_style="bold", expand=True)
        table.add_column("File", overflow="ellipsis", ratio=5, no_wrap=True)
        table.add_column("Original", justify="right", no_wrap=True, min_width=12)
        table.add_column("→ Optimized", justify="right", no_wrap=True, min_width=18)
        table.add_column("Type", no_wrap=True, min_width=10)
        table.add_column("Action", no_wrap=True, min_width=13)

        for item in results:
            is_expansion_skip = "skip expand" in item.action.lower()
            table.add_row(
                item.rel_path,
                self.human_bytes(item.original_size),
                self.optimized_cell(item.optimized_size, item.original_size),
                self.display_type(item.file_type),
                item.action,
                style="yellow" if is_expansion_skip else None,
            )

        image_count = sum(
            1 for item in results if self.split_type_key(item.file_type)[0] == "image"
        )
        video_count = sum(
            1 for item in results if self.split_type_key(item.file_type)[0] == "video"
        )

        CONSOLE.print()
        CONSOLE.print(table)

        would_replace = sum(1 for item in results if item.action == "would replace")
        CONSOLE.print()
        CONSOLE.print(f"Media scanned: {len(self.media_files)}")
        CONSOLE.print(f"  Images: {image_count}")
        CONSOLE.print(f"  Videos: {video_count}")
        CONSOLE.print(f"Hash cache hits: {self.hash_hits}")
        CONSOLE.print(f"Conversion hits: {self.conversion_hits}")
        CONSOLE.print(f"Would replace: {would_replace}")

        if self.errors:
            CONSOLE.print(f"Errors: {self.errors}")
        total_original = sum(item.original_size for item in results)

        # Use estimates for dry-run totals; actual sizes for apply
        if self.apply:
            total_optimized = sum(item.optimized_size for item in results)
        else:
            # Dry-run: calculate from estimates where available
            total_optimized = 0
            if self.debug_enabled:
                self.warn("Totals calculation:")
            for item in results:
                # Skip expansion items from totals (they're not being encoded)
                if "skip expand" in item.action.lower():
                    if self.debug_enabled:
                        self.warn(f"  {item.rel_path}: skipping expansion from totals")
                    continue
                if item.estimate is not None:
                    # Use estimate ratio for videos
                    est_size = int(item.original_size * item.estimate.avg_ratio())
                    total_optimized += est_size
                    if self.debug_enabled:
                        self.warn(
                            f"  {item.rel_path}: {self.human_bytes(item.original_size).strip()} "
                            + f"* {item.estimate.avg_ratio():.3f} = {self.human_bytes(est_size).strip()}"
                        )
                else:
                    # No estimate: assume no savings (images, done, skipped)
                    total_optimized += item.original_size
                    if self.debug_enabled:
                        self.warn(
                            f"  {item.rel_path}: no estimate, using original {self.human_bytes(item.original_size).strip()}"
                        )

        saved_total = total_original - total_optimized
        CONSOLE.print(
            f"Total original size: {self.human_bytes(total_original).strip()}"
        )
        CONSOLE.print()
        CONSOLE.print(
            f"→ Optimized: {self.human_bytes(total_optimized).strip()} "
            + f"({self.savings_pct(total_original, saved_total)})"
        )
        CONSOLE.print()

        CONSOLE.print()

        if self.apply:
            CONSOLE.print(f"Files replaced: {self.applied}")
            CONSOLE.print(f"Skipped (no gain): {self.skipped_no_gain}")
            if self.skipped_expansion > 0:
                CONSOLE.print(
                    f"[yellow]Skipped (expansion): {self.skipped_expansion}[/yellow]"
                )
            # Show total elapsed time
            total_time = time.time() - self.start_time
            CONSOLE.print(f"\nTotal time: {self._format_duration(total_time)}")
            CONSOLE.print(f"\n✓  Done. Cache at: {self.cache_dir}\n")
        else:
            if self.skipped_expansion > 0:
                CONSOLE.print(
                    f"[yellow]⚠ {self.skipped_expansion} video(s) skipped (estimated expansion)[/yellow]"
                )
                CONSOLE.print("[yellow]Use --force-expand to re-encode anyway[/yellow]")
                CONSOLE.print()
            CONSOLE.print(
                "ℹ️  Dry-run — no files modified. Use --apply to convert in-place."
            )
            CONSOLE.print(f"   Cache stored at: {self.cache_dir}\n")

    def run_progress(
        self,
        label: str,
        items: list[Path],
        worker: Callable[[Path, STATE_T], tuple[Path, RESULT_T]],
        state: STATE_T,
        results: dict[Path, RESULT_T] | None = None,
        description_suffix: str = "items",
        max_workers: int | None = None,
    ) -> None:
        total = len(items)
        if total == 0:
            return
        if max_workers is None:
            max_workers = self.jobs
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
        with progress, ThreadPoolExecutor(max_workers=max_workers) as executor:
            futures = {executor.submit(worker, path, state): path for path in items}
            for future in as_completed(futures):
                path = futures[future]
                status = future.result()[1]
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
            return piece[: max(1, width - 1)] + "…"

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
        self.discover_media()
        CONSOLE.print("Checking cache...")

        if loaded:
            CONSOLE.print(f"  (loaded {loaded} cached hashes)")
        entries = self.cache_hashes()
        self.convert_files(entries)

        results = self.collect_results(entries)
        self.render_results(results)
        self.save_cache()
        return 0


def parse_args(argv: Iterable[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Compress images to cached WebP, videos to cached AV1 MP4, and optionally replace originals."
    )
    parser.add_argument("directory", type=Path)
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Convert files in-place using cached optimized output",
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
    parser.add_argument(
        "--force-expand",
        action="store_true",
        help="Re-encode videos even if estimate predicts expansion",
    )
    parser.add_argument(
        "--estimate-only",
        action="store_true",
        help="Sample videos (3 segments) without full encode; show predictions only",
    )
    return parser.parse_args(argv)


def install_signal_handlers(app: App) -> None:
    def handle_interrupt(_signum: int, _frame: object) -> None:
        STOP_EVENT.set()
        CONSOLE.print("\nInterrupted — cleaning up.", style="yellow")
        app.save_cache()
        raise SystemExit(130)

    _ = signal.signal(signal.SIGINT, handle_interrupt)
    _ = signal.signal(signal.SIGTERM, handle_interrupt)


def main(argv: Iterable[str] | None = None) -> int:
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
