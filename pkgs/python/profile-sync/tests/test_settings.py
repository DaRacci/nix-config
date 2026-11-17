"""Settings: dot-path granularity, preservation, unsets, locks, overrides."""

from __future__ import annotations

import json

from profile_sync.document import ConfigDocument
from profile_sync.status import Status

from .conftest import load_policy, make_profile, run_sync, write_override, write_policy

CONFIG = """\
# Hand-maintained: this comment must survive a reconcile.
model:
  default: deepseek-v4.1-flash
  provider: opencode-go
sessions:
  auto_archive: yes  # YAML 1.1 boolean
streaming:
  legacy_flag: on  # untouched YAML 1.1 boolean
sentinel_key: keep-me
curator:
  enabled: false
  stale_after_days: 90
  prune_builtins: no  # sibling of a key the policy rewrites
"""


def test_dot_path_granularity_leaves_siblings_alone(home):
    write_policy(home)
    profile = make_profile(home, "alpha", CONFIG)

    assert run_sync(home) == 0
    text = (profile / "config.yaml").read_text()

    assert "stale_after_days: 30" in text
    assert "prune_builtins: false" in text
    assert "default: deepseek-v4.1-flash" in text


def test_sentinel_key_and_comment_survive(home):
    write_policy(home)
    profile = make_profile(home, "alpha", CONFIG)

    run_sync(home)
    text = (profile / "config.yaml").read_text()

    assert "sentinel_key: keep-me" in text
    assert "# Hand-maintained: this comment must survive a reconcile." in text
    assert "# YAML 1.1 boolean" in text


def test_yaml_1_1_booleans_stay_booleans(home):
    write_policy(home)
    profile = make_profile(home, "alpha", CONFIG)

    run_sync(home)
    text = (profile / "config.yaml").read_text()

    assert "auto_archive: false" in text
    assert "auto_archive: yes" not in text
    document = ConfigDocument(profile / "config.yaml")
    assert document.get("streaming.legacy_flag") == (True, True)


def test_settings_unset_deletes_a_dot_path(home):
    write_policy(
        home,
        defaults={
            "settings": {"curator": {"enabled": True}},
            "settingsUnset": ["curator.stale_after_days"],
        },
        classes={},
        profiles={},
    )
    profile = make_profile(home, "alpha", CONFIG)

    assert run_sync(home) == 0
    text = (profile / "config.yaml").read_text()
    assert "stale_after_days" not in text
    assert "sentinel_key: keep-me" in text


def test_override_wins_over_nix_and_logs_runtime(home, capsys):
    write_policy(home)
    profile = make_profile(home, "alpha", CONFIG)
    write_override(home, "alpha", {"settings": {"agent": {"max_turns": 220}}})

    assert run_sync(home) == 0
    assert "agent:\n  max_turns: 220\n" in (profile / "config.yaml").read_text()
    assert Status.RUNTIME in capsys.readouterr().out


def test_locked_setting_rejects_the_override_with_exit_2(home, capsys):
    write_policy(home)
    profile = make_profile(home, "alpha", CONFIG)
    write_override(home, "alpha", {"settings": {"sessions": {"auto_archive": True}}})

    assert run_sync(home) == 2
    out = capsys.readouterr().out
    assert "REJECTED" in out
    assert "false" in (profile / "config.yaml").read_text()


def test_rejected_override_still_applies_the_rest(home):
    write_policy(home)
    profile = make_profile(home, "alpha", CONFIG)
    write_override(
        home,
        "alpha",
        {
            "settings": {"sessions": {"auto_archive": True}},
            "env": {"set": {"EXTRA_FLAG": "1"}},
        },
    )

    assert run_sync(home) == 2
    assert "EXTRA_FLAG=1" in (profile / ".env").read_text()


def test_new_profile_gets_defaults_only(home, capsys):
    write_policy(home)
    make_profile(home, "stranger", CONFIG)

    assert run_sync(home) == 0
    assert "no policy entry" in capsys.readouterr().out


def test_redundant_restatement_is_reported_in_json(home):
    write_policy(home)
    make_profile(home, "alpha", CONFIG)

    run_sync(home, json=True, verbose=True)
    state = json.loads((home / "state" / "profile-sync" / "last-run.json").read_text())
    assert set(state["profiles"]) == {"alpha", "gamma", "beta"}


def test_policy_file_missing_is_an_error(home, capsys):
    make_profile(home, "alpha", CONFIG)
    assert run_sync(home) == 1
    assert "policy manifest not found" in capsys.readouterr().err


def test_manifest_credential_tripwire_blocks_the_run(home, capsys):
    write_policy(home)
    make_profile(home, "alpha", CONFIG)
    path = home / "state" / "profile-sync" / "policy.json"
    document = json.loads(path.read_text())
    document["profiles"]["alpha"] = {
        "settings": {"api_token": "eyJhbGciOiJIUzI1NiJ9.x"}
    }
    path.write_text(json.dumps(document))

    assert run_sync(home) == 1
    assert "credential" in capsys.readouterr().err


def test_load_policy_round_trips_the_fixture(home):
    write_policy(home)
    policy = load_policy(home)
    assert policy.resolve("alpha").env_inherit
