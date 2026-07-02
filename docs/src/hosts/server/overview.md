# Server Hosts

## Purpose

Documentation of the individual server host machines managed by this repository.

## Architecture / Services / Scope

### Entry Points

- [NixAI](nixai.md): AI agent and inference host
- [NixArr](nixarr.md): Media management and playback host
- [NixCloud](nixcloud.md): Application host, user-facing cloud services
- [NixDev](nixdev.md): Development, CI, and registry host
- [NixIO](nixio.md): Ingress host, reverse proxy, and network gateway
- [NixMon](nixmon.md): Monitoring and observability host
- [NixStor](nixstor.md): Storage host, SeaweedFS evaluation

### Configuration Structure

Host-specific configurations live in `hosts/server/{hostname}/default.nix`.
Services are gated per host via flake allocations (see [Flake Allocations](../../modules/flake/allocations.md)) so that each service runs on exactly one host.

## Operational Notes / Assumptions

- Servers depend on the Database Coordinator for startup ordering (see [IO Guardian](../../components/io_guardian.md)).
- Shared secrets for all server hosts are stored in the [shared file](../../../../hosts/server/secrets.yaml).

## References

- [Adding a New Host](../../development/adding_a_new_host.md)
- [Database Coordinator](nixdb.md)
