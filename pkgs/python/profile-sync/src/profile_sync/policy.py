"""The policy manifest and its per-profile resolution.

The manifest declares three kinds of layer: `defaults`, `classes` and `profiles`. Each
has the same shape, and a key resolves down the chain defaults -> class chain -> profile,
with the runtime override applied last.
"""

from __future__ import annotations

import fnmatch
import json
import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

MANIFEST_VERSION = 1

# A value that must never reach the store or the manifest. `{"secret": path}` is the
# only sanctioned way to carry a credential, and it carries a path, not a value.
_CREDENTIAL_PATTERNS = (
    re.compile(r"^eyJ[A-Za-z0-9_-]{8,}\."),  # JWT
    re.compile(r"^sk-[A-Za-z0-9_-]{16,}$"),  # OpenAI-style key
    re.compile(r"^[0-9a-f]{32}$"),  # bare 32-hex secret
    re.compile(r"^[0-9a-f]{40,}$"),  # bare 40+ hex secret
    re.compile(r"^gh[pousr]_[A-Za-z0-9]{20,}$"),  # GitHub token
)


class PolicyError(Exception):
    """The manifest is unusable: wrong version, a leak, or a broken reference."""


def is_credential_shaped(value: str) -> bool:
    """True when a string looks like a secret rather than a path or a plain value."""
    return any(pattern.match(value) for pattern in _CREDENTIAL_PATTERNS)


def is_glob(pattern: str) -> bool:
    return "*" in pattern or "?" in pattern


def _as_str_list(raw: Any, where: str) -> tuple[str, ...]:
    if raw is None:
        return ()
    if not isinstance(raw, list) or not all(isinstance(item, str) for item in raw):
        raise PolicyError(f"{where} must be a list of strings")
    return tuple(raw)


def _as_map(raw: Any, where: str) -> dict[str, Any]:
    if raw is None:
        return {}
    if not isinstance(raw, dict):
        raise PolicyError(f"{where} must be an object")
    return raw


@dataclass(frozen=True)
class Layer:
    """One row of the matrix: the vocabulary, before any inheritance."""

    settings: dict[str, Any] = field(default_factory=dict)
    settings_unset: tuple[str, ...] = ()
    env_inherit: tuple[str, ...] | None = None
    env_set: dict[str, Any] = field(default_factory=dict)
    env_keep: tuple[str, ...] = ()
    env_unset: tuple[str, ...] = ()
    lock_settings: tuple[str, ...] = ()
    lock_env: tuple[str, ...] = ()
    inherits: str | None = None
    cls: str | None = None

    @classmethod
    def from_raw(cls, raw: Any, where: str) -> Layer:
        if raw is None:
            return cls()
        if not isinstance(raw, dict):
            raise PolicyError(f"{where} must be an object")

        env = _as_map(raw.get("env"), f"{where}.env")
        lock = _as_map(raw.get("lock"), f"{where}.lock")

        inherit = env.get("inherit")
        if inherit is not None:
            inherit = _as_str_list(inherit, f"{where}.env.inherit")

        env_set = _as_map(env.get("set"), f"{where}.env.set")
        for key, value in env_set.items():
            if isinstance(value, str) and is_credential_shaped(value):
                raise PolicyError(
                    f"{where}.env.set.{key} looks like a credential; "
                    "declare { secret = <path>; } instead"
                )

        return cls(
            settings=dict(_as_map(raw.get("settings"), f"{where}.settings")),
            settings_unset=_as_str_list(
                raw.get("settingsUnset"), f"{where}.settingsUnset"
            ),
            env_inherit=inherit,
            env_set=dict(env_set),
            env_keep=_as_str_list(env.get("keep"), f"{where}.env.keep"),
            env_unset=_as_str_list(env.get("unset"), f"{where}.env.unset"),
            lock_settings=_as_str_list(lock.get("settings"), f"{where}.lock.settings"),
            lock_env=_as_str_list(lock.get("env"), f"{where}.lock.env"),
            inherits=raw.get("inherits"),
            cls=raw.get("class"),
        )


@dataclass(frozen=True)
class LinkSpec:
    target: str
    source: str


@dataclass(frozen=True)
class LinkSet:
    """One profile's link list, split by whether the profile's policy keeps it."""

    managed: list[LinkSpec] = field(default_factory=list)
    excluded: list[LinkSpec] = field(default_factory=list)

    def __bool__(self) -> bool:
        return bool(self.managed or self.excluded)


@dataclass(frozen=True)
class LinkPolicy:
    """The fleet-wide link list plus per-class deltas."""

    default: tuple[LinkSpec, ...] = ()
    classes: dict[str, tuple[tuple[str, ...], tuple[str, ...]]] = field(
        default_factory=dict
    )
    profiles: dict[str, tuple[tuple[str, ...], tuple[str, ...]]] = field(
        default_factory=dict
    )

    def for_profile(self, name: str, cls: str | None) -> LinkSet:
        """The default list split into what this profile keeps and drops.

        `exclude` drops entries by target or glob, `include` puts a dropped entry
        back, so a profile can override its class. Inclusion names entries of the
        default list; a link that is not declared there does not exist.

        A dropped entry is not merely forgotten: an existing link at its target is
        unlinked, which is what makes a class exclusion a lane separation.
        """
        specs = {spec.target: spec for spec in self.default}
        dropped: set[str] = set()
        for scope in (self.classes.get(cls or ""), self.profiles.get(name)):
            if scope is None:
                continue
            exclude, include = scope
            for pattern in exclude:
                dropped |= set(_match_targets(specs, pattern))
            for pattern in include:
                dropped -= set(_match_targets(specs, pattern))
        return LinkSet(
            managed=[spec for target, spec in specs.items() if target not in dropped],
            excluded=[spec for target, spec in specs.items() if target in dropped],
        )


def _match_targets(specs: dict[str, LinkSpec], pattern: str) -> list[str]:
    return [target for target in specs if fnmatch.fnmatchcase(target, pattern)]


def flatten(node: Any, prefix: str = "") -> dict[str, Any]:
    """Flatten nested settings into dot-paths; lists and scalars are leaves."""
    if isinstance(node, dict):
        flat: dict[str, Any] = {}
        for key, value in node.items():
            flat.update(flatten(value, f"{prefix}.{key}" if prefix else key))
        return flat
    return {prefix: node}


def get_path(root: Any, path: str) -> tuple[bool, Any]:
    node = root
    for part in path.split("."):
        if not isinstance(node, dict) or part not in node:
            return False, None
        node = node[part]
    return True, node


def deep_merge(base: dict[str, Any], overlay: dict[str, Any]) -> dict[str, Any]:
    """Later mapping wins; a non-mapping replaces whatever the earlier layer had."""
    merged = dict(base)
    for key, value in overlay.items():
        if isinstance(merged.get(key), dict) and isinstance(value, dict):
            merged[key] = deep_merge(merged[key], value)
        else:
            merged[key] = value
    return merged


def _locks_path(lock: str, path: str) -> bool:
    """A lock covers its own dot-path and everything below it."""
    return path == lock or path.startswith(f"{lock}.")


@dataclass
class Resolved:
    """The effective, per-key desired state for one profile."""

    settings: dict[str, Any] = field(default_factory=dict)
    settings_unset: list[str] = field(default_factory=list)
    settings_unset_from_override: list[str] = field(default_factory=list)
    env_inherit: list[str] = field(default_factory=list)
    env_set: dict[str, Any] = field(default_factory=dict)
    env_set_from_override: list[str] = field(default_factory=list)
    env_unset: list[str] = field(default_factory=list)
    env_unset_from_override: list[str] = field(default_factory=list)
    settings_from_override: list[str] = field(default_factory=list)
    env_keep: set[str] = field(default_factory=set)
    lock_settings: list[str] = field(default_factory=list)
    lock_env: list[str] = field(default_factory=list)
    redundant: list[str] = field(default_factory=list)
    rejected: list[tuple[str, str]] = field(default_factory=list)

    def settings_locked(self, path: str) -> bool:
        return any(_locks_path(lock, path) for lock in self.lock_settings)

    def env_locked(self, key: str) -> bool:
        return any(_locks_path(lock, key) for lock in self.lock_env)


class Policy:
    """A loaded manifest: defaults, classes and profiles."""

    def __init__(
        self,
        defaults: Layer,
        classes: dict[str, Layer],
        profiles: dict[str, Layer],
        links: LinkPolicy,
    ) -> None:
        self.defaults = defaults
        self.classes = classes
        self.profiles = profiles
        self.links = links

    @classmethod
    def load(cls, path: Path) -> Policy:
        try:
            raw = json.loads(path.read_text(encoding="utf-8"))
        except FileNotFoundError as exc:
            raise PolicyError(f"policy manifest not found: {path}") from exc
        except json.JSONDecodeError as exc:
            raise PolicyError(f"policy manifest is not valid JSON: {exc}") from exc
        return cls.from_dict(raw, source=str(path))

    @classmethod
    def from_dict(cls, raw: Any, source: str = "<memory>") -> Policy:
        if not isinstance(raw, dict):
            raise PolicyError(f"{source}: manifest must be an object")
        version = raw.get("version")
        if version != MANIFEST_VERSION:
            raise PolicyError(
                f"{source}: unsupported manifest version {version!r}, "
                f"expected {MANIFEST_VERSION}"
            )
        _check_no_credentials(raw, source)

        classes = {
            name: Layer.from_raw(body, f"classes.{name}")
            for name, body in _as_map(raw.get("classes"), "classes").items()
        }
        profiles = {
            name: Layer.from_raw(body, f"profiles.{name}")
            for name, body in _as_map(raw.get("profiles"), "profiles").items()
        }
        return cls(
            defaults=Layer.from_raw(raw.get("defaults"), "defaults"),
            classes=classes,
            profiles=profiles,
            links=_link_policy(raw.get("links")),
        )

    def class_chain(self, name: str) -> list[Layer]:
        """The class and its ancestors, outermost first."""
        chain: list[Layer] = []
        seen: set[str] = set()
        current: str | None = name
        while current is not None:
            if current in seen:
                raise PolicyError(f"class inheritance cycle at {current!r}")
            seen.add(current)
            layer = self.classes.get(current)
            if layer is None:
                raise PolicyError(f"unknown class {current!r}")
            chain.append(layer)
            current = layer.inherits
        return list(reversed(chain))

    def resolve(self, name: str, override: Layer | None = None) -> Resolved:
        """Resolve one profile down the layer chain, then apply its override."""
        entry = self.profiles.get(name)
        chain = self.class_chain(entry.cls) if entry is not None and entry.cls else []
        nix_layers = [self.defaults, *chain]
        if entry is not None:
            nix_layers.append(entry)

        settings: dict[str, Any] = {}
        for layer in nix_layers:
            settings = deep_merge(settings, layer.settings)

        resolved = Resolved(
            settings=settings,
            lock_settings=list(_union(layer.lock_settings for layer in nix_layers)),
            lock_env=list(_union(layer.lock_env for layer in nix_layers)),
            env_keep=set(_union(layer.env_keep for layer in nix_layers)),
            settings_unset=list(_union(layer.settings_unset for layer in nix_layers)),
            env_unset=list(_union(layer.env_unset for layer in nix_layers)),
        )

        for layer in nix_layers:
            if layer.env_inherit is not None:
                resolved.env_inherit = list(layer.env_inherit)
        for layer in nix_layers:
            resolved.env_set = {**resolved.env_set, **layer.env_set}

        resolved.redundant = _redundant_paths(nix_layers)

        if override is not None:
            _apply_override(resolved, override)
        return resolved


def _union(lists) -> tuple[str, ...]:
    seen: dict[str, None] = {}
    for items in lists:
        for item in items:
            seen.setdefault(item, None)
    return tuple(seen)


def _redundant_paths(layers: list[Layer]) -> list[str]:
    """Dot-paths a lower layer restates at the same value as the layer above it."""
    redundant: list[str] = []
    inherited: dict[str, Any] = {}
    for layer in layers[:-1]:
        inherited.update(flatten(layer.settings))
    if not inherited:
        return redundant
    for path, value in flatten(layers[-1].settings).items():
        if path in inherited and inherited[path] == value:
            redundant.append(path)
    return redundant


def _apply_override(resolved: Resolved, override: Layer) -> None:
    for path in flatten(override.settings):
        if resolved.settings_locked(path):
            resolved.rejected.append(("settings", path))
            continue
        resolved.settings = _set_path(
            resolved.settings, path, _value_at(override.settings, path)
        )
        resolved.settings_from_override.append(path)

    for path in override.settings_unset:
        if resolved.settings_locked(path):
            resolved.rejected.append(("settings", path))
            continue
        resolved.settings_unset.append(path)
        resolved.settings_unset_from_override.append(path)

    for key, value in override.env_set.items():
        if resolved.env_locked(key):
            resolved.rejected.append(("env", key))
            continue
        resolved.env_set[key] = value
        resolved.env_set_from_override.append(key)

    for key in override.env_inherit or ():
        if key not in resolved.env_inherit:
            resolved.env_inherit.append(key)

    for pattern in override.env_unset:
        resolved.env_unset.append(pattern)
        resolved.env_unset_from_override.append(pattern)


def _value_at(root: dict[str, Any], path: str) -> Any:
    found, value = get_path(root, path)
    if not found:
        raise PolicyError(f"internal: {path} vanished from the override")
    return value


def _set_path(root: dict[str, Any], path: str, value: Any) -> dict[str, Any]:
    *parents, leaf = path.split(".")
    node = root
    for part in parents:
        child = node.get(part)
        if not isinstance(child, dict):
            child = {}
            node[part] = child
        node = child
    node[leaf] = value
    return root


def _link_policy(raw: Any) -> LinkPolicy:
    raw = _as_map(raw, "links")

    def spec(entry: Any, where: str) -> LinkSpec:
        if (
            not isinstance(entry, dict)
            or "target" not in entry
            or "source" not in entry
        ):
            raise PolicyError(f"{where} must be an object with target and source")
        target, source = entry["target"], entry["source"]
        if not isinstance(target, str) or not isinstance(source, str):
            raise PolicyError(f"{where} target and source must be strings")
        if target.startswith("/"):
            raise PolicyError(f"{where}.target must be relative to the profile home")
        if not source.startswith("/"):
            raise PolicyError(f"{where}.source must be an absolute path")
        return LinkSpec(target=target, source=source)

    def deltas(
        raw: Any, where: str
    ) -> dict[str, tuple[tuple[str, ...], tuple[str, ...]]]:
        return {
            name: (
                _as_str_list(
                    _as_map(body, f"{where}.{name}").get("exclude"), "exclude"
                ),
                _as_str_list(
                    _as_map(body, f"{where}.{name}").get("include"), "include"
                ),
            )
            for name, body in _as_map(raw, where).items()
        }

    return LinkPolicy(
        default=tuple(
            spec(entry, f"links.default[{index}]")
            for index, entry in enumerate(raw.get("default") or [])
        ),
        classes=deltas(raw.get("classes"), "links.classes"),
        profiles=deltas(raw.get("profiles"), "links.profiles"),
    )


def _check_no_credentials(node: Any, where: str) -> None:
    """Refuse a manifest that carries a value instead of a path."""
    if isinstance(node, dict):
        for key, value in node.items():
            if key == "secret":
                continue
            _check_no_credentials(value, f"{where}.{key}")
    elif isinstance(node, list):
        for index, value in enumerate(node):
            _check_no_credentials(value, f"{where}[{index}]")
    elif isinstance(node, str) and is_credential_shaped(node):
        raise PolicyError(
            f"{where}: manifest carries a credential-shaped string; "
            "the policy declares paths, never values"
        )
