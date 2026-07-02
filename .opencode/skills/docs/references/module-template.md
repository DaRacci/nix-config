# {Module Name} — {Short Description}

## Purpose

{Clear explanation of what this module does, its role in the broader system, and why it exists.}

## Entry Point

- **Main file**: [`{relative path to module entry point}`]({relative path})
- **Supporting files**: (List any other key files, e.g. `options.nix`, `config.nix`, sub-modules)

## Architecture / Services / Scope

{Detailed breakdown of the module's behavior, options, and how it integrates with the rest of the system. Use tables or lists for clarity.}

### Options

{For documented modules, you MUST use the build-time generated option fragment via `{{#include}}`.}

{{#include {relative path to generated options fragment}}}

{Use prose for special explanation, caveats, or examples rather than duplicating every option.}

### Coordinator References

{If the module depends on or coordinates with other hosts, refer to them by their generic role name (e.g. "IO Coordinator", "Database Coordinator", "Identity Coordinator") rather than their hostname. Provide a link to the coordinator host page in the References section below.}

## Secrets

{If applicable, document any secrets required by this module.}

### Declared secrets

| Secret key | Purpose |
| ---------- | ------- |
| ...        | ...     |

{Additional details about secrets generation or usage.}

## Operational Notes / Assumptions

{Caveats, specific startup ordering, hardcoded paths, expected environment, or how to operate/troubleshoot.}

## References

- [{Upstream reference or other relevant resource Title}]({relative url})
- [IO Coordinator](../../hosts/server/nixio.md) {example coordinator link}
