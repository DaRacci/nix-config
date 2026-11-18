# profile-sync

Reconciles every Hermes profile's `config.yaml` and `.env` against the policy that nix declares, plus a per-profile runtime override file.

The policy lives at `$HERMES_HOME/state/profile-sync/policy.json` and is installed by the nix module `services.ai-agent.profileSync`.
The runtime override lives at `$HERMES_HOME/state/profile-sync/overrides/<profile>.json`.

Three layers are resolved per key: the nix policy (`defaults` -> class -> profile), then the runtime override.
Precedence is override > profile > class > defaults, and a key no layer mentions is never touched.

## Vocabulary

| Term | Meaning |
| --- | --- |
| `settings` | nested config keys, written at dot-path granularity |
| `settingsUnset` | dot-paths that must end up absent |
| `env.inherit` | key names copied from the container's own `$HERMES_HOME/.env` |
| `env.set` | a literal, or `{"secret": "<path>"}` read at reconcile time |
| `env.unset` | keys or globs that must end up absent |
| `env.keep` | exempts a key from an `unset` rule declared by a higher layer |
| `lock` | keys a runtime override may not change |
| `class` / `inherits` | the class a profile belongs to, and the class a class starts from; together they build the layer chain |

## Links

`links.default` reconciles the symlink matrix in each profile's shell home, `profiles/<name>/home/`, so every `target` stays relative to that home.

An `exclude` is a deletion: an existing link to the excluded spec's own source is unlinked and reported as `REMOVED`, while a real file or a link to another source stays put.
`--dry-run` reports the removal and writes nothing.

Statuses: `NEW` (link created), `RELINK` (link repointed), `ALIAS` (link repointed to the canonical spelling), `MATCH` (identical real file replaced by the link), `OK` (already converged), `REMOVED` (excluded link unlinked), `CONFLICT` (divergent real file left alone), `WARN` (nothing changed).

## Flags

```text
--dry-run        print a unified diff and write nothing
--profile NAME   restrict to one profile (repeatable)
--force          convert a divergent real file into a link (backed up first)
--json           print the run report as JSON
--quiet          print nothing unless a run fails
--verbose        also report OK / KEPT / REDUNDANT outcomes
```

Exit codes: `0` converged, `1` error, `2` at least one override was rejected.
