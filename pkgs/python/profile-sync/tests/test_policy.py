"""Policy resolution: the layer chain, the vocabulary and the tripwires."""

from __future__ import annotations

import pytest
from profile_sync.policy import Layer, Policy, PolicyError, flatten

from .conftest import policy_document


def build(**overrides) -> Policy:
    document = policy_document()
    document.update(overrides)
    return Policy.from_dict(document)


def test_profile_inherits_defaults_and_class():
    policy = build()
    resolved = policy.resolve("alpha")
    assert resolved.settings["code_execution"]["mode"] == "project"
    assert resolved.settings["agent"]["max_turns"] == 150
    assert "agent" not in policy.defaults.settings


def test_profile_wins_over_class_and_defaults():
    policy = build()
    resolved = policy.resolve("gamma")
    assert resolved.settings["curator"]["stale_after_days"] == 14
    assert resolved.settings["curator"]["enabled"] is True


def test_class_inheritance_chain():
    policy = build()
    chain = policy.class_chain("derived")
    assert [layer is policy.classes["base"] for layer in chain] == [True, False]
    resolved = policy.resolve("beta")
    assert resolved.settings["agent"]["max_turns"] == 150


def test_class_inheritance_cycle_is_rejected():
    policy = build(
        classes={
            "a": {"inherits": "b"},
            "b": {"inherits": "a"},
        },
        profiles={"alpha": {"class": "a"}},
    )
    with pytest.raises(PolicyError, match="cycle"):
        policy.resolve("alpha")


def test_unknown_class_is_rejected():
    policy = build(profiles={"alpha": {"class": "nope"}})
    with pytest.raises(PolicyError, match="unknown class"):
        policy.resolve("alpha")


def test_inherit_is_replaced_by_a_lower_layer():
    policy = build()
    assert policy.resolve("alpha").env_inherit == [
        "OPENROUTER_API_KEY",
        "SEARXNG_URL",
        "SUDO_PASSWORD",
    ]
    # `restricted` declares its own list, which drops the fleet credential.
    assert policy.resolve("gamma").env_inherit == ["SUDO_PASSWORD"]


def test_unset_is_the_union_minus_keep():
    policy = build(
        defaults={
            "env": {"unset": ["A", "B"]},
            "settings": {},
        },
        classes={},
        profiles={"alpha": {"env": {"keep": ["B"]}}},
    )
    resolved = policy.resolve("alpha")
    assert resolved.env_unset == ["A", "B"]
    assert resolved.env_keep == {"B"}


def test_override_replaces_settings_and_is_recorded():
    policy = build()
    resolved = policy.resolve(
        "alpha", Layer.from_raw({"settings": {"agent": {"max_turns": 220}}}, "o")
    )
    assert resolved.settings["agent"]["max_turns"] == 220
    assert "agent.max_turns" in resolved.settings_from_override


def test_override_on_a_locked_key_is_rejected():
    policy = build()
    override = Layer.from_raw({"settings": {"sessions": {"auto_archive": True}}}, "o")
    resolved = policy.resolve("alpha", override)
    assert resolved.rejected == [("settings", "sessions.auto_archive")]
    assert resolved.settings["sessions"]["auto_archive"] is False


def test_lock_covers_the_subtree():
    policy = build()
    override = Layer.from_raw({"settings": {"sessions": {"auto_archive_days": 3}}}, "o")
    resolved = policy.resolve("alpha", override)
    assert resolved.rejected == []

    policy = build(
        defaults={"settings": {}, "lock": {"settings": ["sessions"]}},
    )
    resolved = policy.resolve("alpha", override)
    assert resolved.rejected == [("settings", "sessions.auto_archive_days")]


def test_override_inherit_is_additive():
    policy = build()
    override = Layer.from_raw({"env": {"inherit": ["N8N_BASE_URL"]}}, "o")
    resolved = policy.resolve("alpha", override)
    assert resolved.env_inherit[-1] == "N8N_BASE_URL"
    assert "OPENROUTER_API_KEY" in resolved.env_inherit


def test_manifest_rejects_a_credential_shaped_value():
    document = policy_document()
    document["profiles"]["alpha"]["env"] = {"set": {"LEAK": "sk-" + "a" * 32}}
    with pytest.raises(PolicyError, match="credential"):
        Policy.from_dict(document)


def test_manifest_accepts_a_secret_path():
    document = policy_document()
    document["profiles"]["alpha"]["env"] = {"set": {"OK": {"secret": "/run/secrets/x"}}}
    Policy.from_dict(document)


def test_manifest_version_is_enforced():
    document = policy_document()
    document["version"] = 2
    with pytest.raises(PolicyError, match="version"):
        Policy.from_dict(document)


def test_layer_reads_the_nested_encoding():
    layer = Layer.from_raw({"env": {"unset": ["A"]}, "lock": {"env": ["B"]}}, "x")
    assert layer.env_unset == ("A",)
    assert layer.lock_env == ("B",)


def test_flatten_keeps_lists_and_scalars_as_leaves():
    assert flatten({"a": {"b": [1, 2], "c": True}}) == {"a.b": [1, 2], "a.c": True}


def test_profile_without_an_entry_gets_defaults_only():
    policy = build()
    resolved = policy.resolve("stranger")
    assert resolved.settings["curator"]["enabled"] is True
    assert "agent" not in resolved.settings


def test_redundant_reports_a_lower_layer_restating_the_default():
    policy = build(
        profiles={
            "alpha": {"class": "base", "settings": {"curator": {"enabled": True}}}
        }
    )
    assert policy.resolve("alpha").redundant == ["curator.enabled"]


def test_link_policy_excludes_by_class():
    policy = build()
    targets = [
        spec.target for spec in policy.links.for_profile("gamma", "restricted").managed
    ]
    assert targets == [".cargo", ".m2"]
    assert [
        spec.target for spec in policy.links.for_profile("gamma", "restricted").excluded
    ] == [".gitconfig"]
    targets = [
        spec.target for spec in policy.links.for_profile("alpha", "base").managed
    ]
    assert targets == [".gitconfig", ".cargo", ".m2"]


def test_link_policy_profile_include_overrides_a_class_exclude():
    policy = build(
        links={
            "default": [{"target": ".gitconfig", "source": "/src/gitconfig"}],
            "classes": {"restricted": {"exclude": [".gitconfig"]}},
            "profiles": {"gamma": {"include": [".gitconfig"]}},
        }
    )
    links = policy.links.for_profile("gamma", "restricted")
    assert [s.target for s in links.managed] == [".gitconfig"]
    assert links.excluded == []


def test_link_targets_must_be_relative_and_sources_absolute():
    with pytest.raises(PolicyError, match="relative"):
        build(links={"default": [{"target": "/etc/x", "source": "/src/x"}]})
    with pytest.raises(PolicyError, match="absolute"):
        build(links={"default": [{"target": ".x", "source": "src/x"}]})
