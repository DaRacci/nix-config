# {Host Name} — {Short Description}

## Purpose

{Clear explanation of what this host does, its role in the broader system, and why it exists.}

## Entry Point

- **Main file**: [`{relative path to host default.nix}`]({relative path})
- **Supporting files**: (List any other key files, e.g. `hardware.nix`, JSON mappings, secrets overrides)

## Architecture / Services / Scope

{Detailed breakdown of the services running on this host, its architectural role, and its features. Use tables or lists for clarity.}

### Coordinator References

{If the host depends on or coordinates with other hosts, refer to them by their generic role name (e.g. "IO Coordinator", "Database Coordinator", "Identity Coordinator") rather than their hostname. Provide a link to the coordinator host page in the References section below.}

## Secrets

{If applicable, document any secrets required by this host.}

### Declared secrets

| Secret key | Purpose |
| ---------- | ------- |
| ...        | ...     |

{Additional details about secrets generation or usage.}

## Operational Notes / Assumptions

{Caveats, specific startup ordering, hardcoded paths, expected environment, or how to operate/troubleshoot.}

## References

- [{Upstream reference or other relevant resource Title}]({url})
- [IO Coordinator](../../hosts/server/nixio.md)  {example coordinator link}
