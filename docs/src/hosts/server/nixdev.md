# nixdev — Development & CI

## Purpose

`nixdev` is the development and CI host.
It runs the self-hosted development services: continuous integration, Coder workspace platform, workflow automation, a Docker registry, and a forgesync mirror job.

## Entry Point

- **Main file**: [`hosts/server/nixdev/default.nix`](../../../../hosts/server/nixdev/default.nix)
- **Supporting files**: `automation.nix`, `ci.nix`, `coder.nix`, `forgesync.nix`, `registry.nix`, `woodpecker.nix`

## Architecture / Services / Scope

### CI / Automation

- **Woodpecker CI**: Self-hosted CI server + local Docker-backed agent, supporting GitHub and Codeberg forges. Served on its own vhost with a separate gRPC agent endpoint.
- **GitHub Actions runners**: A pool of 10 self-hosted `nixos-runner-*` runners for the `nix-config` repo.

### Workspaces

- **Coder**: Self-hosted development workspaces, backed by the Docker daemon. Coder users are granted Docker access.

### Workflow Automation

- **n8n**: Workflow automation with task runners, backed by PostgreSQL and Redis on the Database Coordinator.

### Registry & Mirroring

- **Docker Registry**: Self-hosted OCI registry storing images on the Storage Coordinator, with htpasswd auth.
- **Forgesync**: Mirrors repositories between Codeberg and GitHub on a daily schedule.

## Secrets

### Declared secrets

| Secret key                                                 | Purpose                           |
| ---------------------------------------------------------- | --------------------------------- |
| `GITHUB_TOKEN`                                             | Token for the self-hosted runners |
| `POSTGRES/N8N_PASSWORD`                                    | n8n database password             |
| `POSTGRES/CODER_PASSWORD`                                  | Coder database password           |
| `POSTGRES/WOODPECKER_PASSWORD`                             | Woodpecker database password      |
| `POSTGRES/WINDMILL_PASSWORD`                               | Windmill database password        |
| `REDIS_PASSWORD`                                           | n8n Redis password                |
| `N8N/ENCRYPTION_KEY`                                       | n8n encryption key                |
| `N8N/RUNNER_AUTH_TOKEN`                                    | n8n task runner auth              |
| `WOODPECKER/GRPC_SECRET`                                   | Woodpecker gRPC secret            |
| `WOODPECKER/AGENT_SECRET`                                  | Woodpecker agent secret           |
| `WOODPECKER/GITHUB_CLIENT` / `GITHUB_SECRET`               | GitHub forge OAuth                |
| `WOODPECKER/CODEBERG_CLIENT` / `CODEBERG_SECRET`           | Codeberg forge OAuth              |
| `REGISTRY/SECRET`                                          | Registry shared secret            |
| `REGISTRY/HTPASSWD`                                        | Registry auth htpasswd            |
| `REGISTRY/S3_ACCESS_KEY` / `S3_SECRET_KEY`                 | S3 storage credentials            |
| `FORGESYNC/SOURCE_TOKEN` / `TARGET_TOKEN` / `MIRROR_TOKEN` | Forgesync tokens                  |

## Operational Notes / Assumptions

- Runs Docker with auto-pruning for workspaces and CI workloads.
- Woodpecker, n8n, Coder, the registry, and CI are exposed through the IO Coordinator reverse proxy.
- Databases are provided by the Database Coordinator; n8n and Woodpecker depend on the database availability target.

## References

- [Woodpecker CI](https://woodpecker-ci.org)
- [Coder](https://coder.com)
- [n8n](https://n8n.io)
- [Database Coordinator](../../hosts/server/nixdb.md)
- [Storage Coordinator](../../hosts/server/nixstor.md)
- [IO Coordinator](../../hosts/server/nixio.md)
