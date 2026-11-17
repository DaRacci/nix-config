# AI — Profile Config Sync

## Purpose

Reconcile every Hermes profile's `config.yaml` and `.env` against a nix-declared matrix, with a bounded runtime override per profile.

## Entry Point

- **Main file**: [profile-sync.nix](../../../../../modules/nixos/ai/agents/hermes/profile-sync.nix)
- **Reconciler**: `pkgs/python/profile-sync.nix` — a packaged Python application with `ruamel.yaml`.

The module splits into one file per area under `profile-sync/`: `settings.nix` (config keys), `env.nix` (`.env` keys) and `links.nix` (the profile-home symlink matrix).
Each contributes its own option vocabulary and its own slice of the compiled policy, and `lib.nix` holds the shared helpers.

## Architecture / Services / Scope

Three layers, resolved per key:

1. **nix declaration** — `services.ai-agent.profileSync`, compiled to `$HERMES_HOME/state/profile-sync/policy.json` at activation.
1. **runtime override** — `$HERMES_HOME/state/profile-sync/overrides/<profile>.json`, written by an agent, never by nix.
1. **profile artefact** — `profiles/<name>/config.yaml` and `profiles/<name>/.env`, written only by the reconciler.

Precedence is **override > profile > class > defaults**.
A key no layer mentions is never touched, and a profile with no entry in `profiles` gets `defaults` only.

Both units live on the host and reach into the container with `docker exec`:

- `hermes-profile-sync.service` — `Type=oneshot`, `After=docker.service hermes-agent.service`, and `restartTriggers` on the compiled policy, so a rebuild that changes the policy converges immediately instead of waiting for the timer.
- `hermes-profile-sync.timer` — `OnBootSec=2min`, `OnUnitActiveSec=<interval>` (default `3h`), `Persistent=true`.

One run is one event: `$HERMES_HOME/state/profile-sync/last-run.json` records the timestamp, every profile that changed, and how many keys were pruned or rejected.
The detail goes to the journal.
Only files that actually change are backed up, under `$HERMES_HOME/backups/profile-sync/<UTC timestamp>/<profile>/`, and five runs are retained.

### Vocabulary

| Verb | Meaning |
| --- | --- |
| `settings` | config keys written at dot-path granularity; siblings and comments survive |
| `settingsUnset` | dot-paths that must end up absent; deleting a node removes its subtree |
| `env."inherit"` | key names copied from the container's own `$HERMES_HOME/.env` |
| `env.set` | a literal, or `{ secret = <path>; }` read at reconcile time |
| `env.unset` | keys or globs that must end up absent |
| `env.keep` | exempts a key from an `unset` rule declared by a higher layer |
| `lock` | keys a runtime override may not change |

A lower layer's `env."inherit"` list **replaces** the one it inherits; the runtime override's list is additive.

### Locks

A lock is enforced twice.
At evaluation, a nix layer that assigns a conflicting value to a locked key fails the build.
At run time a lock is not a failure: the override is skipped, the rest of the override applies, and the run exits `2` so the rejection is visible.

### Links

`links` reconciles the profile-home symlink matrix in the same run, through the same binary and timer: a fleet-wide `default` list plus per-class and per-profile `include`/`exclude` deltas.

Links land in `profiles/<name>/home/`, the shell home the profile's shell and toolchains read, and every `target` is relative to it.

- Every status is decided from `test -e` on the source and on the target's resolved path.
- `MATCH` replaces a real file or directory whose content is identical to the source.
- A divergent real file is `CONFLICT` and is left untouched; `--force` converts it after moving the original into the backup root.
- No path that resolves into the link source is ever modified, so a directory-level link cannot delete the canonical file.
- An `exclude` is a deletion: a link that resolves to that spec's own source is unlinked and reported as `REMOVED`.
  A real file, or a link to another source, is `WARN` and left in place, and nothing outside the profile home is touched.
  `--dry-run` reports the removal and writes nothing.

### What it never touches

The module refuses to compile a policy that names a host-owned or generated setting:
a key equal to one of the roots below, or anywhere beneath it, fails the assertion.
`profile-sync/lib.nix` holds the list; these are its roots:

`_config_version`, `command_allowlist`, `context`, `dashboard`, `delegation.model`, `delegation.provider`,
`display.pet`, `display.skin`, `gateway.profile_routes`, `kanban.dispatch_profiles`, `mcp_servers`,
`memory.mnemosyne.ignore_patterns`, `memory.mnemosyne.reflect`, `memory.mnemosyne.sync_roles`, `moa`,
`platform_toolsets`, `platforms.webhook`, `skills.disabled`, `telemetry.shared_metrics`, `tts`.

## Usage

```nix
{ config, ... }: {
  services.ai-agent.profileSync = {
    enable = true;
    interval = "3h";

    defaults = {
      settings = {
        feature.enabled = true;
        feature.limit = 30;
      };
      env."inherit" = [
        "EXAMPLE_API_KEY"
        "EXAMPLE_TOKEN"
      ];
      env.unset = [ "LEGACY_*" ];
      # Two layers assigning different values to a locked key fails the build, so
      # `feature.enabled` is left out of the profile deltas below.
      lock = {
        settings = [ "feature.enabled" ];
        env = [ "EXAMPLE_API_KEY" ];
      };
    };

    classes = {
      common = { };
      special.inherits = "common";
      scoped.env."inherit" = [ "EXAMPLE_TOKEN" ];
    };

    profiles = {
      first.class = "common";
      second.class = "special";
      third = {
        class = "scoped";
        settings.feature.limit = 14;
        env.set.EXAMPLE_FLAG = {
          secret = config.sops.secrets."EXAMPLE/FLAG".path;
        };
      };
    };

    links = {
      default = [
        {
          target = ".exampleconfig";
          source = "/home/hermes/.exampleconfig";
        }
        {
          target = ".example";
          source = "/home/hermes/.example";
        }
      ];
      classes.scoped.exclude = [ ".exampleconfig" ];
    };
  };
}
```

A secret is declared as a path, never a value.
The manifest carries `{ "secret": "<path>" }`, so nothing credential-shaped reaches the Nix store, and both the module and the reconciler refuse a manifest that carries a credential instead of a path.

### Runtime override

An agent can adjust its own profile without a rebuild.
Everything the nix layer expresses is available, minus `lock` and `class`:

```json
{
  "settings": { "agent.max_turns": 220 },
  "settingsUnset": [ "curator.prune_builtins" ],
  "env.set": { "EXTRA_FLAG": "1" },
  "env.inherit": [ "N8N_BASE_URL" ],
  "env.unset": [ "MNEMOSYNE_LLM_*" ]
}
```

## Operational Notes / Assumptions

- `enable` requires `services.hermes-agent.container.enable`.
- Check a run with `systemctl status hermes-profile-sync` and `journalctl -u hermes-profile-sync`; the reconciler itself is silent when the fleet is already converged.
- `--dry-run` prints a unified diff and writes nothing, including no backup, no state file, no link and no removal.
- `--profile <name>` restricts a run to one profile.
- A profile that exists on disk without a policy entry is listed as undeclared on every run, which is the signal to give it a class.

## References

- [Agents](agents.md) — the agent container this reconciles
- [Mnemosyne](mnemosyne.md) — the memory provider whose settings the policy carries
