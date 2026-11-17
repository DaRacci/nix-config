"""Run-level behaviour: idempotency, dry-run, state file, backup retention."""

from __future__ import annotations

import hashlib
import json

from .conftest import make_profile, run_sync, write_override, write_policy

CONFIG = """\
# comment
curator:
  enabled: false
sentinel: 1
"""

ENV = """\
SEARXNG_URL=https://search.example
API_SERVER_ENABLED=true
"""


def hashes(root):
    return {
        str(path.relative_to(root)): hashlib.sha256(path.read_bytes()).hexdigest()
        for path in sorted(root.rglob("*"))
        if path.is_file()
    }


def test_second_run_is_byte_identical_and_silent(home, capsys):
    write_policy(home)
    profile = make_profile(home, "alpha", CONFIG, ENV)

    assert run_sync(home) == 0
    capsys.readouterr()
    first = {
        name: hashlib.sha256((profile / name).read_bytes()).hexdigest()
        for name in ("config.yaml", ".env")
    }

    assert run_sync(home) == 0
    assert capsys.readouterr().out == ""
    second = {
        name: hashlib.sha256((profile / name).read_bytes()).hexdigest()
        for name in ("config.yaml", ".env")
    }
    assert first == second


def test_dry_run_writes_nothing(home, capsys):
    write_policy(home)
    make_profile(home, "alpha", CONFIG, ENV)
    before = hashes(home)

    assert run_sync(home, dry_run=True) == 0
    out = capsys.readouterr().out

    assert "--- alpha/config.yaml" in out
    assert hashes(home) == before
    assert not (home / "state" / "profile-sync" / "last-run.json").exists()
    assert not (home / "backups" / "profile-sync").exists()


def test_dry_run_diff_shows_the_change(home, capsys):
    write_policy(home)
    make_profile(home, "alpha", CONFIG, ENV)

    assert run_sync(home, dry_run=True) == 0
    out = capsys.readouterr().out
    assert "-  enabled: false" in out
    assert "+  enabled: true" in out


def test_state_file_records_the_run(home):
    write_policy(home)
    make_profile(home, "alpha", CONFIG, ENV)

    assert run_sync(home) == 0
    state = json.loads((home / "state" / "profile-sync" / "last-run.json").read_text())

    assert "alpha" in state["changed"]
    assert state["pruned"] >= 1
    assert state["rejected"] == 0
    assert set(state["profiles"]) == {"alpha", "gamma", "beta"}
    assert state["profiles"]["beta"]["warnings"] == ["profile missing"]


def test_backups_are_kept_and_rolled_off(home):
    write_policy(home)
    make_profile(home, "alpha", CONFIG, ENV)
    root = home / "backups" / "profile-sync"
    for index in range(8):
        (root / f"2026010{index}T000000Z" / "alpha").mkdir(parents=True)

    assert run_sync(home) == 0
    runs = sorted(entry.name for entry in root.iterdir() if entry.is_dir())
    assert len(runs) == 5
    assert "20260107T000000Z" in runs
    backups = list(root.glob("*/alpha/config.yaml"))
    assert backups
    assert "enabled: false" in backups[0].read_text()


def test_profile_filter_only_touches_one_profile(home):
    write_policy(home)
    alpha = make_profile(home, "alpha", CONFIG, ENV)
    other = make_profile(home, "beta", CONFIG, ENV)
    before = (other / "config.yaml").read_text()

    assert run_sync(home, profile="alpha") == 0
    assert (other / "config.yaml").read_text() == before
    assert "enabled: true" in (alpha / "config.yaml").read_text()


def test_unknown_profile_is_an_error(home, capsys):
    write_policy(home)
    make_profile(home, "alpha", CONFIG, ENV)

    assert run_sync(home, profile="nope") == 1
    assert "unknown profile" in capsys.readouterr().err


def test_json_report_is_machine_readable(home, capsys):
    write_policy(home)
    make_profile(home, "alpha", CONFIG, ENV)

    assert run_sync(home, json=True) == 0
    report = json.loads(capsys.readouterr().out)
    assert set(report) == {"ts", "changed", "pruned", "rejected", "profiles"}
    assert report["rejected"] == 0
    assert report["profiles"]["alpha"]["changed"] is True


def test_quiet_still_reports_a_rejection(home, capsys):
    write_policy(home)
    make_profile(home, "alpha", CONFIG, ENV)
    write_override(home, "alpha", {"settings": {"sessions": {"auto_archive": True}}})

    assert run_sync(home, quiet=True) == 2
    out = capsys.readouterr().out
    assert "REJECTED" in out
    assert "OVERRIDE" not in out
