import csv
import importlib.util
import sys
import tempfile
import types
import unittest
from argparse import Namespace
from pathlib import Path
from typing import ClassVar

import pytest


class _DummyConsole:
    def print(self, *args, **kwargs):
        return None


class _DummyProgress:
    def __init__(self, *args, **kwargs):
        return None

    def add_task(self, *args, **kwargs):
        return 1

    def update(self, *args, **kwargs):
        return None

    def advance(self, *args, **kwargs):
        return None

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, tb):
        return False


class _DummyColumn:
    def __init__(self, *args, **kwargs):
        return None


class _DummyTable:
    def __init__(self, *args, **kwargs):
        self.rows = []

    def add_column(self, *args, **kwargs):
        return None

    def add_row(self, *args, **kwargs):
        self.rows.append(args)


class _DummyImageHandle:
    def verify(self):
        return None

    def load(self):
        return None

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, tb):
        return False


class _DummyImageModule:
    @staticmethod
    def open(_path):
        return _DummyImageHandle()


class _DependencyStubs:
    @staticmethod
    def install() -> None:
        magic_mod = types.ModuleType("magic")
        magic_mod.MagicException = RuntimeError
        magic_mod.from_file = lambda _path, mime=True: "image/png"
        sys.modules["magic"] = magic_mod

        pil_mod = types.ModuleType("PIL")
        pil_mod.Image = _DummyImageModule
        pil_mod.UnidentifiedImageError = OSError
        sys.modules["PIL"] = pil_mod

        rich_mod = types.ModuleType("rich")
        sys.modules["rich"] = rich_mod

        rich_console_mod = types.ModuleType("rich.console")
        rich_console_mod.Console = _DummyConsole
        sys.modules["rich.console"] = rich_console_mod

        rich_progress_mod = types.ModuleType("rich.progress")
        rich_progress_mod.BarColumn = _DummyColumn
        rich_progress_mod.Progress = _DummyProgress
        rich_progress_mod.SpinnerColumn = _DummyColumn
        rich_progress_mod.TextColumn = _DummyColumn
        rich_progress_mod.TimeElapsedColumn = _DummyColumn
        sys.modules["rich.progress"] = rich_progress_mod

        rich_table_mod = types.ModuleType("rich.table")
        rich_table_mod.Table = _DummyTable
        sys.modules["rich.table"] = rich_table_mod


_DefModuleName = "image_compressor_under_test"


def load_module():
    _DependencyStubs.install()
    spec = importlib.util.spec_from_file_location(
        _DefModuleName,
        Path(__file__).with_name("compressor.py"),
    )
    module = importlib.util.module_from_spec(spec)
    sys.modules[_DefModuleName] = module
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


class ImageCompressorTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.mod = load_module()

    def make_app(self, directory: Path, *, apply: bool = False):
        args = Namespace(
            directory=directory,
            apply=apply,
            jobs=1,
            debug=False,
            cache_dir=directory / ".cache",
        )
        return self.mod.App(args)

    def test_hash_cache_round_trips_done_column(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            cache_file = Path(tmpdir) / "hashcache.tsv"
            cache = self.mod.HashCache(cache_file)
            cache.update(
                Path(tmpdir) / "photo.jpg",
                self.mod.CacheEntry(
                    mtime_ns=1,
                    size=2,
                    sha256="deadbeef",
                    file_type="image:webp",
                    done=True,
                ),
            )
            cache.save()

            with cache_file.open("r", encoding="utf-8", newline="") as handle:
                rows = list(csv.reader(handle, delimiter="\t"))

            self.assertEqual(rows[0][-2], "done")
            self.assertEqual(rows[1][-2], "1")
            self.assertEqual(rows[0][-1], "video_estimate_json")
            self.assertEqual(rows[1][-1], "")

            reloaded = self.mod.HashCache(cache_file)
            self.assertEqual(reloaded.load(), 1)
            entry = reloaded.entries[str(Path(tmpdir) / "photo.jpg")]
            self.assertTrue(entry.done)
            self.assertEqual(entry.file_type, "image:webp")

    def test_detect_kind_accepts_application_mp4_alias(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            app = self.make_app(Path(tmpdir))
            original_magic = self.mod.magic.from_file
            self.mod.magic.from_file = lambda _path, mime=True: "application/mp4"
            try:
                self.assertEqual(app.detect_kind(Path(tmpdir) / "clip.bin"), "video")
            finally:
                self.mod.magic.from_file = original_magic

    def test_file_type_uses_video_codec_for_video_files(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            media_path = Path(tmpdir) / "clip.mkv"
            media_path.write_bytes(b"not-a-real-video")
            app = self.make_app(Path(tmpdir))
            original_magic = self.mod.magic.from_file
            self.mod.magic.from_file = lambda _path, mime=True: "video/mp4"
            app.video_codec = lambda _path: "av1"
            try:
                self.assertEqual(app.file_type(media_path), "video:av1")
            finally:
                self.mod.magic.from_file = original_magic

    def test_verify_video_output_accepts_av1_only(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            app = self.make_app(Path(tmpdir))
            original_file_type = app.file_type
            app.file_type = lambda _path: "video:av1"
            try:
                self.assertTrue(app.verify_video_output(Path(tmpdir) / "clip.mp4"))
            finally:
                app.file_type = original_file_type

            app.file_type = lambda _path: "video:h264"
            try:
                self.assertFalse(
                    app.verify_video_output(Path(tmpdir) / "clip.mp4", warn=False)
                )
            finally:
                app.file_type = original_file_type

    def test_build_video_command_matches_av1_preset_core_flags(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            app = self.make_app(Path(tmpdir))
            command = app.build_video_command(
                Path("/tmp/source.mkv"),
                Path("/tmp/output.mp4"),
            )

            self.assertEqual(
                command[:6],
                [
                    "HandBrakeCLI",
                    "--json",
                    "-i",
                    "/tmp/source.mkv",
                    "-o",
                    "/tmp/output.mp4",
                ],
            )
            self.assertIn("--format", command)
            self.assertIn("av_mp4", command)
            self.assertIn("--encoder", command)
            self.assertIn("svt_av1", command)
            self.assertIn("--encoder-preset", command)
            self.assertIn("6", command)
            self.assertIn("--encoder-tune", command)
            self.assertIn("vq", command)
            self.assertIn("--quality", command)
            self.assertIn("30", command)
            self.assertIn("--multi-pass", command)
            self.assertIn("--vfr", command)
            self.assertIn("--align-av", command)
            self.assertIn("--keep-metadata", command)
            self.assertIn("--markers", command)
            self.assertIn("--audio-copy-mask", command)
            self.assertIn("aac,ac3", command)
            self.assertIn("--audio-fallback", command)
            self.assertIn("av_aac", command)
            self.assertIn("-E", command)
            self.assertIn("av_aac,copy:ac3", command)
            self.assertIn("-B", command)
            self.assertIn("160,640", command)
            self.assertIn("-6", command)
            self.assertIn("stereo,none", command)
            self.assertIn("--crop-mode", command)
            self.assertIn("auto", command)
            self.assertIn("-X", command)
            self.assertIn("3840", command)
            self.assertIn("-Y", command)
            self.assertIn("2160", command)
            self.assertIn("--comb-detect", command)
            self.assertIn("--decomb", command)
            self.assertIn("-s", command)
            self.assertIn("scan", command)
            self.assertIn("--subtitle-forced", command)
            self.assertIn("--subtitle-burned", command)

    def test_collect_results_keeps_replaced_action_after_apply(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            directory = Path(tmpdir)
            media_path = directory / "photo.jpg"
            media_path.write_bytes(b"abcdef")
            app = self.make_app(directory, apply=True)
            app.media_files = [media_path]

            entry = self.mod.CacheEntry(
                mtime_ns=media_path.stat().st_mtime_ns,
                size=media_path.stat().st_size,
                sha256="deadbeef",
                file_type="image:jpeg",
                done=False,
            )
            cached = app.cache_output_path(entry.sha256, entry.file_type)
            assert cached is not None
            cached.write_bytes(b"a")

            replaced_entry = self.mod.CacheEntry(
                mtime_ns=media_path.stat().st_mtime_ns,
                size=1,
                sha256="beadfeed",
                file_type="image:webp",
                done=True,
            )

            def fake_run_progress(
                _label, items, _worker, _state, results=None, description_suffix="items"
            ):
                self.assertEqual(items, [media_path])
                self.assertEqual(description_suffix, "replacement(s)")
                assert results is not None
                results[media_path] = self.mod.ApplyResult("replaced", replaced_entry)

            app.run_progress = fake_run_progress
            results = app.collect_results({media_path: entry})

            self.assertEqual(len(results), 1)
            self.assertEqual(results[0].action, "✓ replaced")

    def test_convert_one_keeps_existing_cache_if_rebuild_fails(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            directory = Path(tmpdir)
            media_path = directory / "photo.jpg"
            media_path.write_bytes(b"abcdef")
            app = self.make_app(directory)

            entry = self.mod.CacheEntry(
                mtime_ns=media_path.stat().st_mtime_ns,
                size=media_path.stat().st_size,
                sha256="deadbeef",
                file_type="image:jpeg",
                done=False,
            )
            cached = app.cache_output_path(entry.sha256, entry.file_type)
            assert cached is not None
            cached.write_bytes(b"old-cache")

            original_verify = app.verify_target_output
            original_build = app.build_image_command
            original_run = self.mod.subprocess.run
            app.verify_target_output = lambda _path, _kind, warn=False: False
            app.build_image_command = lambda source, output: [
                "fake-convert",
                str(source),
                str(output),
            ]
            self.mod.subprocess.run = lambda *args, **kwargs: types.SimpleNamespace(
                returncode=1
            )
            try:
                self.assertFalse(app.convert_one(media_path, entry))
            finally:
                app.verify_target_output = original_verify
                app.build_image_command = original_build
                self.mod.subprocess.run = original_run

            self.assertTrue(cached.exists())
            self.assertEqual(cached.read_bytes(), b"old-cache")


def test_extract_segment(tmp_path):
    mod = load_module()
    args = Namespace(
        directory=tmp_path,
        apply=False,
        jobs=1,
        debug=False,
        cache_dir=tmp_path / "cache",
    )
    app = mod.App(args)

    src_video = tmp_path / "test.mp4"
    src_video.write_bytes(b"mock mp4")

    original_run = mod.subprocess.run
    mod.subprocess.run = lambda *args, **kwargs: types.SimpleNamespace(returncode=0)
    try:
        segment = app.extract_segment(src_video, start_seconds=10.0)
        assert segment is not None
        assert segment.exists()
        assert segment.suffix == ".mp4"
    finally:
        mod.subprocess.run = original_run


def test_get_crf_for_video(tmp_path):
    mod = load_module()
    args = Namespace(
        directory=tmp_path,
        apply=False,
        jobs=1,
        debug=False,
        cache_dir=tmp_path / "cache",
    )
    app = mod.App(args)

    # Mock ffprobe to return 1080p resolution -> CRF 30
    original_run = mod.subprocess.run

    def fake_run_1080p(*args, **kwargs):
        return types.SimpleNamespace(
            returncode=0,
            stdout="1920\n1080\n",
            stderr="",
        )

    mod.subprocess.run = fake_run_1080p
    try:
        crf = app.get_crf_for_video(tmp_path / "test_1080p.mp4")
        assert crf == 30
    finally:
        mod.subprocess.run = original_run

    # Mock ffprobe to return 4K resolution -> CRF 26
    def fake_run_4k(*args, **kwargs):
        return types.SimpleNamespace(
            returncode=0,
            stdout="3840\n2160\n",
            stderr="",
        )

    mod.subprocess.run = fake_run_4k
    try:
        crf_4k = app.get_crf_for_video(tmp_path / "test_4k.mp4")
        assert crf_4k == 26
    finally:
        mod.subprocess.run = original_run


def test_encode_segment_only(tmp_path):
    mod = load_module()
    args = Namespace(
        directory=tmp_path,
        apply=False,
        jobs=1,
        debug=False,
        cache_dir=tmp_path / "cache",
    )
    app = mod.App(args)

    segment_file = tmp_path / "segment.mp4"
    segment_file.write_bytes(b"mock segment" * 100)

    original_run = mod.subprocess.run

    seen_command = []

    def fake_handbrake(*args, **kwargs):
        # Write a fake output file so stat().st_size works
        # The output path is the second positional arg after -o
        cmd = args[0]
        seen_command[:] = cmd
        out_idx = cmd.index("-o") + 1
        out_path = Path(cmd[out_idx])
        out_path.write_bytes(b"encoded output" * 50)
        return types.SimpleNamespace(returncode=0)

    mod.subprocess.run = fake_handbrake
    try:
        size = app.encode_segment_only(segment_file, crf=30)
        assert size is not None
        assert size > 0
        assert "--json" not in seen_command
    finally:
        mod.subprocess.run = original_run


def test_encode_segment_only_uses_live_json_when_progress_requested(tmp_path):
    mod = load_module()
    args = Namespace(
        directory=tmp_path,
        apply=False,
        jobs=1,
        debug=False,
        cache_dir=tmp_path / "cache",
    )
    app = mod.App(args)

    segment_file = tmp_path / "segment.mp4"
    segment_file.write_bytes(b"mock segment" * 100)

    captured_command = []
    original_runner = app.run_video_command

    def fake_run_video_command(command, progress_callback=None):
        captured_command[:] = command
        assert progress_callback is not None
        out_idx = command.index("-o") + 1
        Path(command[out_idx]).write_bytes(b"encoded output" * 50)
        progress_callback(mod.HandBrakeProgress(0.5, 12, 1, 1), 3.0)
        return 0

    app.run_video_command = fake_run_video_command
    try:
        size = app.encode_segment_only(
            segment_file,
            crf=30,
            progress_callback=lambda progress, elapsed: None,
        )
        assert size is not None
        assert size > 0
        assert "--json" in captured_command
    finally:
        app.run_video_command = original_runner


def test_video_sample_estimate():
    mod = load_module()

    # Segment sizes: [100, 150, 120] bytes
    # Original sizes: [200, 220, 210] bytes
    # Avg ratio: (100+150+120) / (200+220+210) = 370/630 ≈ 0.587
    # Savings: 100 - 58.7 = 41.3%
    est = mod.VideoSampleEstimate([100, 150, 120], [200, 220, 210])
    assert est.avg_ratio() == pytest.approx(370.0 / 630.0, rel=0.01)
    assert est.avg_savings_pct() == pytest.approx(41.3, rel=1)
    assert not est.will_expand()  # Saves, doesn’t expand

    # Expand case: encoded > original
    est2 = mod.VideoSampleEstimate([250, 280, 260], [200, 220, 210])
    assert est2.avg_ratio() > 1.0
    assert est2.will_expand()  # Crosses 5% threshold


def test_iter_handbrake_progress_parses_multiline_json_blocks(tmp_path):
    mod = load_module()
    args = Namespace(
        directory=tmp_path,
        apply=False,
        jobs=1,
        debug=False,
        cache_dir=tmp_path / "cache",
    )
    app = mod.App(args)

    updates = list(
        app.iter_handbrake_progress(
            [
                "[15:18:38] hb_init: starting libhb thread\n",
                "Progress: {\n",
                '    "State": "WORKING",\n',
                '    "Working": {\n',
                '        "ETASeconds": 91,\n',
                '        "Pass": 1,\n',
                '        "PassCount": 2,\n',
                '        "Progress": 0.25,\n',
                '        "SequenceID": 1\n',
                "    }\n",
                "}\n",
                "Progress: {\n",
                '    "State": "WORKDONE",\n',
                '    "WorkDone": {\n',
                '        "Error": 0,\n',
                '        "SequenceID": 1\n',
                "    }\n",
                "}\n",
            ]
        )
    )

    assert len(updates) == 1
    assert updates[0].fraction == pytest.approx(0.25)
    assert updates[0].eta_seconds == 91
    assert updates[0].current_pass == 1
    assert updates[0].pass_count == 2


class _SpyProgress:
    instances: ClassVar[list["_SpyProgress"]] = []

    def __init__(self, *args, **kwargs):
        self.tasks = {}
        self.updates = []
        type(self).instances.append(self)

    def add_task(self, description, total, **kwargs):
        task_id = len(self.tasks) + 1
        self.tasks[task_id] = {
            "description": description,
            "total": total,
            "completed": 0,
            **kwargs,
        }
        return task_id

    def update(self, task_id, **kwargs):
        self.tasks[task_id].update(kwargs)
        self.updates.append((task_id, dict(self.tasks[task_id])))

    def advance(self, task_id, advance=1):
        self.tasks[task_id]["completed"] += advance
        self.updates.append((task_id, dict(self.tasks[task_id])))

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, tb):
        return False


def test_run_video_command_emits_live_progress_callbacks(tmp_path):
    mod = load_module()
    args = Namespace(
        directory=tmp_path,
        apply=False,
        jobs=1,
        debug=False,
        cache_dir=tmp_path / "cache",
    )
    app = mod.App(args)
    seen = []

    class _FakePopen:
        def __init__(self, *args, **kwargs):
            self.stdout = iter(
                [
                    "HandBrake 1.11.2\n",
                    "Progress: {\n",
                    '    "State": "WORKING",\n',
                    '    "Working": {\n',
                    '        "ETASeconds": 120,\n',
                    '        "Pass": 1,\n',
                    '        "PassCount": 2,\n',
                    '        "Progress": 0.25\n',
                    "    }\n",
                    "}\n",
                    "Progress: {\n",
                    '    "State": "WORKING",\n',
                    '    "Working": {\n',
                    '        "ETASeconds": 40,\n',
                    '        "Pass": 2,\n',
                    '        "PassCount": 2,\n',
                    '        "Progress": 0.75\n',
                    "    }\n",
                    "}\n",
                ]
            )
            self.stderr = iter(["debug noise\n"])
            self.returncode = 0

        def wait(self):
            return self.returncode

    original_popen = mod.subprocess.Popen
    mod.subprocess.Popen = _FakePopen
    try:
        returncode = app.run_video_command(
            ["HandBrakeCLI", "--json"],
            progress_callback=lambda progress, elapsed: seen.append(
                (
                    progress.fraction,
                    progress.eta_seconds,
                    progress.current_pass,
                    progress.pass_count,
                    elapsed,
                )
            ),
        )
    finally:
        mod.subprocess.Popen = original_popen

    assert returncode == 0
    assert [(item[0], item[1], item[2], item[3]) for item in seen] == [
        (0.25, 120, 1, 2),
        (0.75, 40, 2, 2),
    ]
    assert all(item[4] >= 0 for item in seen)


def test_estimate_sample_queue_eta_uses_current_sample_runtime(tmp_path):
    mod = load_module()
    args = Namespace(
        directory=tmp_path,
        apply=False,
        jobs=1,
        debug=False,
        cache_dir=tmp_path / "cache",
    )
    app = mod.App(args)

    queue_eta = app.estimate_sample_queue_eta(
        mod.HandBrakeProgress(0.25, 120, 1, 1),
        elapsed=30.0,
        sample_index=1,
        sample_count=3,
    )

    assert queue_eta == pytest.approx(420.0)


def test_estimate_current_video_eta_falls_back_to_elapsed_progress(tmp_path):
    mod = load_module()
    args = Namespace(
        directory=tmp_path,
        apply=False,
        jobs=1,
        debug=False,
        cache_dir=tmp_path / "cache",
    )
    app = mod.App(args)

    eta = app.estimate_current_video_eta(
        mod.HandBrakeProgress(0.25, 0, 1, 1),
        elapsed=30.0,
    )

    assert eta == pytest.approx(90.0)


def test_estimate_video_queue_eta_uses_current_handbrake_eta(tmp_path):
    mod = load_module()
    args = Namespace(
        directory=tmp_path,
        apply=False,
        jobs=1,
        debug=False,
        cache_dir=tmp_path / "cache",
    )
    app = mod.App(args)

    queue_eta = app.estimate_video_queue_eta(
        current_eta_seconds=120,
        current_fraction=0.25,
        current_duration=100.0,
        current_elapsed=30.0,
        remaining_durations=[200.0, None, 0.0],
        completed_timings=[],
    )

    assert queue_eta == pytest.approx(420.0)


def test_estimate_video_queue_eta_falls_back_to_progress_ratio(tmp_path):
    mod = load_module()
    args = Namespace(
        directory=tmp_path,
        apply=False,
        jobs=1,
        debug=False,
        cache_dir=tmp_path / "cache",
    )
    app = mod.App(args)

    queue_eta = app.estimate_video_queue_eta(
        current_eta_seconds=0,
        current_fraction=0.25,
        current_duration=100.0,
        current_elapsed=30.0,
        remaining_durations=[200.0],
        completed_timings=[],
    )

    assert queue_eta == pytest.approx(330.0)


def test_convert_videos_updates_live_eta_during_sample_estimation(tmp_path):
    mod = load_module()
    args = Namespace(
        directory=tmp_path,
        apply=False,
        jobs=1,
        debug=False,
        cache_dir=tmp_path / "cache",
    )
    _SpyProgress.instances = []
    app = mod.App(args)

    video = tmp_path / "alpha.mp4"
    video.write_bytes(b"video-one")
    entry = mod.CacheEntry(
        mtime_ns=video.stat().st_mtime_ns,
        size=video.stat().st_size,
        sha256="alpha",
        file_type="video:h264",
    )
    entries = {video: entry}

    original_progress = mod.Progress
    original_estimate = app.estimate_video_expansion
    original_duration = app.video_duration_seconds
    original_run_video_command = app.run_video_command
    original_verify = app.verify_target_output
    mod.Progress = _SpyProgress
    app.video_duration_seconds = lambda path: 100.0
    app.verify_target_output = lambda _path, _kind, warn=True: True

    def fake_estimate_video_expansion(path, progress_callback=None):
        assert progress_callback is not None
        progress_callback(
            mod.VideoSampleProgress(
                progress=mod.HandBrakeProgress(0.25, 120, 1, 1),
                elapsed=30.0,
                sample_index=1,
                sample_count=3,
                sample_duration=5.0,
            )
        )
        progress_callback(
            mod.VideoSampleProgress(
                progress=mod.HandBrakeProgress(0.75, 40, 1, 1),
                elapsed=90.0,
                sample_index=2,
                sample_count=3,
                sample_duration=5.0,
            )
        )
        return mod.VideoSampleEstimate([100, 110, 120], [200, 200, 200])

    def fake_run_video_command(command, progress_callback=None):
        out_idx = command.index("-o") + 1
        Path(command[out_idx]).write_bytes(b"encoded")
        return 0

    app.estimate_video_expansion = fake_estimate_video_expansion
    app.run_video_command = fake_run_video_command
    try:
        results = {}
        app.convert_videos_with_progress([video], entries, results)
    finally:
        mod.Progress = original_progress
        app.estimate_video_expansion = original_estimate
        app.video_duration_seconds = original_duration
        app.run_video_command = original_run_video_command
        app.verify_target_output = original_verify

    assert results == {video: True}
    spy = _SpyProgress.instances[-1]
    estimate_updates = [
        task
        for _task_id, task in spy.updates
        if task["description"].startswith("Estimating ")
    ]
    sample_updates = [
        task
        for _task_id, task in spy.updates
        if task["description"].startswith("Sample ")
    ]

    assert any(task.get("eta") == "7.0m" for task in estimate_updates)
    assert any(task.get("eta") == "2.8m" for task in estimate_updates)
    assert any(task.get("eta") == "2.0m" for task in sample_updates)
    assert any(task.get("eta") == "40.0s" for task in sample_updates)


def test_convert_videos_updates_live_eta_in_progress_bar(tmp_path):
    mod = load_module()
    args = Namespace(
        directory=tmp_path,
        apply=False,
        jobs=1,
        debug=False,
        cache_dir=tmp_path / "cache",
    )
    _SpyProgress.instances = []
    app = mod.App(args)

    video1 = tmp_path / "alpha.mp4"
    video2 = tmp_path / "beta.mp4"
    video1.write_bytes(b"video-one")
    video2.write_bytes(b"video-two")

    entry1 = mod.CacheEntry(
        mtime_ns=video1.stat().st_mtime_ns,
        size=video1.stat().st_size,
        sha256="alpha",
        file_type="video:h264",
    )
    entry2 = mod.CacheEntry(
        mtime_ns=video2.stat().st_mtime_ns,
        size=video2.stat().st_size,
        sha256="beta",
        file_type="video:h264",
    )
    entries = {
        video1: entry1,
        video2: entry2,
    }

    original_progress = mod.Progress
    original_convert_one = app.convert_one
    original_duration = app.video_duration_seconds
    mod.Progress = _SpyProgress
    app.video_duration_seconds = lambda path: {
        video1: 100.0,
        video2: 200.0,
    }[path]

    def fake_convert_one(
        path,
        entry,
        progress_callback=None,
        estimate_progress_callback=None,
    ):
        if progress_callback is not None:
            progress_callback(mod.HandBrakeProgress(0.25, 120, 1, 2), 30.0)
            progress_callback(mod.HandBrakeProgress(0.75, 40, 2, 2), 90.0)
        cached = app.cache_output_path(entry.sha256, entry.file_type)
        assert cached is not None
        cached.write_bytes(b"encoded")
        app.video_encode_times[path] = 130.0
        return True

    app.convert_one = fake_convert_one
    try:
        results = {}
        app.convert_videos_with_progress([video1, video2], entries, results)
    finally:
        mod.Progress = original_progress
        app.convert_one = original_convert_one
        app.video_duration_seconds = original_duration

    assert results == {video1: True, video2: True}
    spy = _SpyProgress.instances[-1]
    queue_updates = [
        task
        for _task_id, task in spy.updates
        if task["description"] == "Converting video(s)"
    ]
    current_updates = [
        task
        for _task_id, task in spy.updates
        if task["description"].startswith("Encoding ")
    ]

    assert any(task.get("eta") == "7.0m" for task in queue_updates)
    assert any(task.get("eta") == "5.0m" for task in queue_updates)
    assert any(task.get("eta") == "2.0m" for task in current_updates)
    assert any(task.get("eta") == "40.0s" for task in current_updates)


def test_estimate_video_expansion(tmp_path):
    mod = load_module()
    args = Namespace(
        directory=tmp_path,
        apply=False,
        jobs=1,
        debug=False,
        cache_dir=tmp_path / "cache",
    )
    app = mod.App(args)

    video_file = tmp_path / "test.mp4"
    video_file.write_bytes(b"mock video" * 1000)

    original_run = mod.subprocess.run

    def fake_run(*args, **kwargs):
        cmd = args[0]
        # ffprobe duration query
        if "ffprobe" in str(cmd) and "format=duration" in str(cmd):
            return types.SimpleNamespace(returncode=0, stdout="120.0\n", stderr="")
        # ffprobe resolution query (get_crf_for_video)
        if "ffprobe" in str(cmd) and "stream=width,height" in str(cmd):
            return types.SimpleNamespace(returncode=0, stdout="1920\n1080\n", stderr="")
        # ffmpeg extract segment
        if "ffmpeg" in str(cmd):
            out_path = Path(cmd[-1])
            out_path.write_bytes(b"segment data" * 100)
            return types.SimpleNamespace(returncode=0)
        # HandBrakeCLI encode segment
        if "HandBrakeCLI" in str(cmd):
            out_idx = cmd.index("-o") + 1
            out_path = Path(cmd[out_idx])
            out_path.write_bytes(b"encoded data" * 50)
            return types.SimpleNamespace(returncode=0)
        return types.SimpleNamespace(returncode=0)

    mod.subprocess.run = fake_run
    try:
        estimate = app.estimate_video_expansion(video_file)
        assert estimate is not None
        assert len(estimate.segment_sizes) == 3
        assert len(estimate.original_segments) == 3
        assert not estimate.will_expand()
    finally:
        mod.subprocess.run = original_run


if __name__ == "__main__":
    unittest.main(verbosity=2)
