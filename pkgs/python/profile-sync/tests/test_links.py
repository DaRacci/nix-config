"""Links: every status, the audit that actually touches the filesystem, and --force."""

from __future__ import annotations

import os

from .conftest import make_profile, run_sync, write_policy

CONFIG = "curator:\n  enabled: true\n"


def test_links_are_created_under_the_profile_home(home, src, capsys):
    write_policy(home)
    profile = make_profile(home, "alpha", CONFIG)

    assert run_sync(home, verbose=True) == 0

    assert os.readlink(profile / "home" / ".gitconfig") == str(src / "gitconfig")
    assert not os.path.lexists(profile / ".gitconfig")


def test_new_links_are_created_and_a_dangling_source_warns(home, src, capsys):
    write_policy(
        home,
        links={
            "default": [
                {"target": ".gitconfig", "source": "<SRC>/gitconfig"},
                {"target": ".m2", "source": "<SRC>/gone"},
            ]
        },
        classes={},
        profiles={},
    )
    profile = make_profile(home, "alpha", CONFIG)
    home_dir = profile / "home"

    assert run_sync(home, verbose=True) == 0
    out = capsys.readouterr().out

    assert os.readlink(home_dir / ".gitconfig") == str(src / "gitconfig")
    assert (home_dir / ".gitconfig").exists()
    assert "NEW" in out
    assert ".m2: source missing" in out
    assert not (home_dir / ".m2").exists()


def test_existing_link_to_the_source_is_ok(home, src, capsys):
    write_policy(home)
    profile = make_profile(home, "alpha", CONFIG)
    os.symlink(src / "gitconfig", profile / "home" / ".gitconfig")

    assert run_sync(home, verbose=True) == 0
    assert "\tOK\t.gitconfig" in capsys.readouterr().out


def test_link_pointing_elsewhere_is_relinked(home, src, capsys):
    write_policy(home)
    profile = make_profile(home, "alpha", CONFIG)
    other = home / "elsewhere"
    other.write_text("x")
    os.symlink(other, profile / "home" / ".gitconfig")

    assert run_sync(home) == 0
    assert "RELINK" in capsys.readouterr().out
    assert os.readlink(profile / "home" / ".gitconfig") == str(src / "gitconfig")


def test_alias_link_is_converted_at_the_leaf(home, src):
    write_policy(home)
    profile = make_profile(home, "alpha", CONFIG)
    # Same file, different spelling: resolves to the source but the link text differs.
    os.symlink(src / ".." / "src" / "gitconfig", profile / "home" / ".gitconfig")

    assert run_sync(home) == 0
    assert os.readlink(profile / "home" / ".gitconfig") == str(src / "gitconfig")
    assert (src / "gitconfig").exists()


def test_identical_real_file_is_replaced_by_the_link(home, src):
    write_policy(home)
    profile = make_profile(home, "alpha", CONFIG)
    (profile / "home" / ".gitconfig").write_text((src / "gitconfig").read_text())

    assert run_sync(home) == 0
    assert (profile / "home" / ".gitconfig").is_symlink()
    assert (src / "gitconfig").exists()


def test_identical_real_directory_is_replaced_by_the_link(home, src):
    write_policy(home)
    profile = make_profile(home, "alpha", CONFIG)
    (profile / "home" / ".cargo" / "registry").mkdir(parents=True)
    (profile / "home" / ".cargo" / "registry" / "index").write_text("index\n")

    assert run_sync(home) == 0
    assert (profile / "home" / ".cargo").is_symlink()
    assert (src / "cargo" / "registry" / "index").exists()


def test_divergent_real_file_is_never_overwritten(home, src, capsys):
    write_policy(home)
    profile = make_profile(home, "alpha", CONFIG)
    (profile / "home" / ".gitconfig").write_text("[user]\n  name = Local\n")

    assert run_sync(home) == 0
    out = capsys.readouterr().out
    assert "CONFLICT" in out
    assert not (profile / "home" / ".gitconfig").is_symlink()
    assert "Local" in (profile / "home" / ".gitconfig").read_text()


def test_force_converts_a_divergent_file_with_a_backup(home, src):
    write_policy(home)
    profile = make_profile(home, "alpha", CONFIG)
    (profile / "home" / ".gitconfig").write_text("[user]\n  name = Local\n")

    assert run_sync(home, force=True) == 0
    assert (profile / "home" / ".gitconfig").is_symlink()
    backups = list((home / "backups" / "profile-sync").glob("*/*/links/.gitconfig"))
    assert backups and "Local" in backups[0].read_text()


def test_target_resolving_into_the_source_is_never_touched(home, src, capsys):
    write_policy(
        home,
        links={
            "default": [{"target": ".config/inner", "source": "<SRC>/inner"}],
        },
        classes={},
        profiles={},
    )
    inner = src / "inner"
    inner.write_text("canonical\n")
    profile = make_profile(home, "alpha", CONFIG)
    os.symlink(src, profile / "home" / ".config")

    assert run_sync(home) == 0
    out = capsys.readouterr().out
    assert "CONFLICT" in out
    assert "resolves into the source" in out
    assert inner.read_text() == "canonical\n"
    assert not inner.is_symlink()


def test_force_does_not_override_the_resolves_into_the_source_guard(home, src):
    write_policy(
        home,
        links={"default": [{"target": ".config/inner", "source": "<SRC>/inner"}]},
        classes={},
        profiles={},
    )
    (src / "inner").write_text("canonical\n")
    profile = make_profile(home, "alpha", CONFIG)
    os.symlink(src, profile / "home" / ".config")

    assert run_sync(home, force=True) == 0
    assert (src / "inner").read_text() == "canonical\n"


def test_work_class_gets_no_credential_bearing_links(home, src):
    write_policy(home)
    profile = make_profile(home, "gamma", CONFIG)

    assert run_sync(home, profile="gamma") == 0
    assert not (profile / "home" / ".gitconfig").is_symlink()
    assert (profile / "home" / ".cargo").is_symlink()


def test_excluded_link_is_removed(home, src, capsys):
    write_policy(home)
    profile = make_profile(home, "gamma", CONFIG)
    home_dir = profile / "home"
    os.symlink(src / "gitconfig", home_dir / ".gitconfig")

    assert run_sync(home, profile="gamma") == 0

    assert "\tREMOVED\t.gitconfig" in capsys.readouterr().out
    assert not os.path.lexists(home_dir / ".gitconfig")
    assert os.path.lexists(home_dir / ".cargo")


def test_excluded_real_file_is_not_deleted(home, src, capsys):
    write_policy(home)
    profile = make_profile(home, "gamma", CONFIG)
    target = profile / "home" / ".gitconfig"
    target.write_text("[user]\n  name = Local\n")

    assert run_sync(home, profile="gamma") == 0

    out = capsys.readouterr().out
    assert "\tWARN\t.gitconfig: excluded, but not a link" in out
    assert target.read_text() == "[user]\n  name = Local\n"


def test_excluded_link_to_another_source_is_left_alone(home, src, capsys):
    write_policy(home)
    profile = make_profile(home, "gamma", CONFIG)
    other = home / "elsewhere"
    other.write_text("[user]\n  name = Other\n")
    target = profile / "home" / ".gitconfig"
    os.symlink(other, target)

    assert run_sync(home, profile="gamma") == 0

    out = capsys.readouterr().out
    assert "excluded, but the link points elsewhere" in out
    assert os.readlink(target) == str(other)


def test_excluded_link_dry_run_reports_and_keeps(home, src, capsys):
    write_policy(home)
    profile = make_profile(home, "gamma", CONFIG)
    target = profile / "home" / ".gitconfig"
    os.symlink(src / "gitconfig", target)

    assert run_sync(home, profile="gamma", dry_run=True) == 0

    out = capsys.readouterr().out
    assert "\tREMOVED\t.gitconfig: dry-run" in out
    assert os.path.lexists(target)
