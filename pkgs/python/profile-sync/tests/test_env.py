"""Env: inherit, set, unset value-matching, keep, byte stability."""

from __future__ import annotations

from .conftest import make_profile, run_sync, write_policy

CONFIG = "curator:\n  enabled: true\n"

ENV = """\
# copied from the container
SEARXNG_URL=https://search.example
API_SERVER_ENABLED=true
API_SERVER_KEY=leaked-key
AZURE_FOUNDRY_API_KEY=dead
N8N_LEGACY=leftover
PRIVATE_THING=mine
"""


def test_inherit_copies_the_container_value(home):
    write_policy(home)
    profile = make_profile(home, "alpha", CONFIG, ENV)

    assert run_sync(home) == 0
    assert "OPENROUTER_API_KEY=fleet-openrouter-key" in (profile / ".env").read_text()


def test_inherit_leaves_an_absent_key_alone_with_a_warning(home, capsys):
    write_policy(
        home,
        defaults={
            "settings": {},
            "env": {"inherit": ["NOT_IN_CONTAINER"]},
        },
        classes={},
        profiles={},
    )
    profile = make_profile(home, "alpha", CONFIG, ENV)
    before = (profile / ".env").read_text()

    assert run_sync(home) == 0
    assert "missing in container env" in capsys.readouterr().out
    assert "NOT_IN_CONTAINER" not in (profile / ".env").read_text()
    assert before.splitlines()[0] in (profile / ".env").read_text()


def test_unset_prunes_a_glob_match_whose_value_matches_the_source(home):
    write_policy(home)
    profile = make_profile(home, "alpha", CONFIG, ENV)

    assert run_sync(home) == 0
    text = (profile / ".env").read_text()
    assert "API_SERVER_ENABLED" not in text
    assert "AZURE_FOUNDRY_API_KEY" not in text
    assert "PRIVATE_THING=mine" in text


def test_unset_keeps_a_value_that_differs_from_the_source(home, capsys):
    write_policy(home)
    profile = make_profile(home, "alpha", CONFIG, ENV)

    assert run_sync(home) == 0
    assert "API_SERVER_KEY=leaked-key" in (profile / ".env").read_text()
    assert "local value differs" in capsys.readouterr().out


def test_unset_glob_without_a_source_value_warns_and_keeps(home, capsys):
    write_policy(
        home,
        defaults={"settings": {}, "env": {"unset": ["PRIVATE_*"]}},
        classes={},
        profiles={},
    )
    profile = make_profile(home, "alpha", CONFIG, ENV)

    assert run_sync(home) == 0
    assert "cannot verify" in capsys.readouterr().out
    assert "PRIVATE_THING=mine" in (profile / ".env").read_text()


def test_unset_exact_key_without_a_source_value_prunes(home):
    write_policy(
        home,
        defaults={"settings": {}, "env": {"unset": ["N8N_LEGACY"]}},
        classes={},
        profiles={},
    )
    profile = make_profile(home, "alpha", CONFIG, ENV)

    assert run_sync(home) == 0
    assert "N8N_LEGACY" not in (profile / ".env").read_text()


def test_keep_exempts_an_inherited_unset(home, capsys):
    write_policy(
        home,
        defaults={"settings": {}, "env": {"unset": ["N8N_API_KEY"]}},
        classes={},
        profiles={"alpha": {"env": {"keep": ["N8N_API_KEY"]}}},
    )
    profile = make_profile(home, "alpha", CONFIG, "N8N_API_KEY=alpha-only\n")

    assert run_sync(home, verbose=True) == 0
    assert "N8N_API_KEY=alpha-only" in (profile / ".env").read_text()
    assert "exempt" in capsys.readouterr().out


def test_env_set_reads_a_secret_file(home, secret_file):
    write_policy(home)
    profile = make_profile(home, "gamma", CONFIG, "")
    path = home / "state" / "profile-sync" / "policy.json"

    assert run_sync(home, profile="gamma") == 0
    text = (profile / ".env").read_text()
    assert "SECRET_TOKEN=s3cr3t-value" in text
    assert "s3cr3t-value" not in path.read_text()
    assert str(secret_file) in path.read_text()


def test_missing_secret_file_is_an_error(home):
    write_policy(home)
    make_profile(home, "gamma", CONFIG, "")
    path = home / "state" / "profile-sync" / "policy.json"
    path.write_text(
        path.read_text().replace(str(home.parent / "secret"), "/run/secrets/absent")
    )

    assert run_sync(home, profile="gamma") == 1


def test_env_set_writes_a_literal(home):
    write_policy(home)
    profile = make_profile(home, "gamma", CONFIG, "")

    assert run_sync(home, profile="gamma") == 0
    assert "LANE=restricted" in (profile / ".env").read_text()


def test_untouched_lines_stay_byte_identical(home):
    write_policy(home)
    profile = make_profile(home, "alpha", CONFIG, ENV)
    result = run_sync(home)
    assert result == 0
    lines = (profile / ".env").read_text().splitlines()
    for line in ["# copied from the container", "PRIVATE_THING=mine"]:
        assert line in lines


def test_duplicate_key_is_collapsed_when_written(home, secret_file):
    write_policy(
        home,
        defaults={"settings": {}, "env": {"set": {"DUPE": "one"}}},
        classes={},
        profiles={},
    )
    profile = make_profile(home, "alpha", CONFIG, "DUPE=old\nOTHER=1\nDUPE=older\n")

    assert run_sync(home) == 0
    text = (profile / ".env").read_text()
    assert text.count("DUPE=") == 1
    assert "DUPE=one" in text
    assert "OTHER=1" in text
