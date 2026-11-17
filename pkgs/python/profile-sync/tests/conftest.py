"""Fixtures: a fake HERMES_HOME with a fleet, a policy and an override file."""

from __future__ import annotations

import json
import textwrap
from pathlib import Path

import pytest
from profile_sync.policy import Policy

HOME_ENV = """\
# Container environment, materialised by the activation script.
OPENROUTER_API_KEY=fleet-openrouter-key
OPENCODE_GO_API_KEY=fleet-opencode-key
SEARXNG_URL=https://search.example
N8N_BASE_URL=https://n8n.example
SUDO_PASSWORD=
API_SERVER_ENABLED=true
API_SERVER_KEY=shared-api-key
"""

POLICY = {
    "version": 1,
    "defaults": {
        "settings": {
            "code_execution": {"mode": "project"},
            "curator": {"enabled": True, "stale_after_days": 30},
            "sessions": {"auto_archive": False},
        },
        "env": {
            "inherit": ["OPENROUTER_API_KEY", "SEARXNG_URL", "SUDO_PASSWORD"],
            "unset": ["API_SERVER_*", "AZURE_FOUNDRY_API_KEY", "N8N_LEGACY"],
        },
        "lock": {"settings": ["sessions.auto_archive"], "env": ["OPENROUTER_API_KEY"]},
    },
    "classes": {
        "base": {"settings": {"agent": {"max_turns": 150}}},
        "restricted": {
            "env": {"inherit": ["SUDO_PASSWORD"], "set": {"LANE": "restricted"}},
            "lock": {"env": ["OPENROUTER_API_KEY"]},
        },
        "derived": {"inherits": "base"},
    },
    "profiles": {
        "alpha": {"class": "base"},
        "beta": {"class": "derived"},
        "gamma": {
            "class": "restricted",
            "settings": {"curator": {"stale_after_days": 14}},
            "env": {"set": {"SECRET_TOKEN": {"secret": "<SECRET_PATH>"}}},
        },
    },
    "links": {
        "default": [
            {"target": ".gitconfig", "source": "<SRC>/gitconfig"},
            {"target": ".cargo", "source": "<SRC>/cargo"},
            {"target": ".m2", "source": "<SRC>/m2"},
        ],
        "classes": {"restricted": {"exclude": [".gitconfig"]}},
    },
}


@pytest.fixture
def home(tmp_path: Path) -> Path:
    """A HERMES_HOME with a source tree the links point at."""
    root = tmp_path / "hermes"
    (root / "profiles").mkdir(parents=True)
    (root / "state" / "profile-sync" / "overrides").mkdir(parents=True)
    (root / "backups").mkdir()
    (root / ".env").write_text(HOME_ENV, encoding="utf-8")
    (tmp_path / "secret").write_text("s3cr3t-value\n", encoding="utf-8")

    source = tmp_path / "src"
    (source / "cargo" / "registry").mkdir(parents=True)
    (source / "cargo" / "registry" / "index").write_text("index\n", encoding="utf-8")
    (source / "gitconfig").write_text("[user]\n  name = Test\n", encoding="utf-8")
    (source / "m2" / "repository").mkdir(parents=True)
    (source / "m2" / "repository" / "settings.xml").write_text(
        "<settings/>\n", encoding="utf-8"
    )
    return root


@pytest.fixture
def src(home: Path) -> Path:
    return home.parent / "src"


@pytest.fixture
def secret_file(home: Path) -> Path:
    return home.parent / "secret"


def policy_document(src: str = "/src", secret: str = "/run/secrets/token") -> dict:
    """The fixture matrix with its path placeholders filled in."""
    rendered = json.dumps(POLICY).replace("<SRC>", src).replace("<SECRET_PATH>", secret)
    return json.loads(rendered)


def write_policy(home: Path, policy: dict | None = None, **patches) -> Path:
    """Install a manifest, substituting the fixture paths."""
    document = json.loads(json.dumps(POLICY if policy is None else policy))
    document.update(patches)
    rendered = (
        json.dumps(document)
        .replace("<SRC>", str(home.parent / "src"))
        .replace("<SECRET_PATH>", str(home.parent / "secret"))
    )
    path = home / "state" / "profile-sync" / "policy.json"
    path.write_text(rendered, encoding="utf-8")
    return path


def load_policy(home: Path) -> Policy:
    return Policy.load(home / "state" / "profile-sync" / "policy.json")


def make_profile(home: Path, name: str, config: str, env: str = "") -> Path:
    """A profile directory: config.yaml and .env here, shell links under `home/`."""
    profile = home / "profiles" / name
    (profile / "home").mkdir(parents=True, exist_ok=True)
    (profile / "config.yaml").write_text(textwrap.dedent(config), encoding="utf-8")
    (profile / ".env").write_text(textwrap.dedent(env), encoding="utf-8")
    return profile


def write_override(home: Path, name: str, override: dict) -> Path:
    path = home / "state" / "profile-sync" / "overrides" / f"{name}.json"
    path.write_text(json.dumps(override), encoding="utf-8")
    return path


def run_sync(home: Path, **kwargs) -> int:
    """Run the CLI in-process so the tests can assert on the exit code."""
    from profile_sync.cli import main

    argv = ["--hermes-home", str(home)]
    for flag, value in kwargs.items():
        if value is True:
            argv.append(f"--{flag.replace('_', '-')}")
        elif value not in (None, False):
            argv.extend([f"--{flag.replace('_', '-')}", str(value)])
    return main(argv)
