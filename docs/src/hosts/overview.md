# Hosts Overview

## Purpose

This section covers the configuration of individual host machines. This repository uses an automatic discovery system to manage hosts based on their device type.

## Entry Points

- `hosts/`: Root directory for all host configurations.
- `hosts/desktop/`: Configurations for desktop systems.
- `hosts/laptop/`: Configurations for laptop systems.
- `hosts/server/`: Configurations for server systems.
- `hosts/shared/`: Shared configuration modules applied across multiple hosts.
- `hosts/secrets.yaml`: Root-level encrypted secrets for host configurations.

## Key Options/Knobs

Host-specific configurations are found in `hosts/{device-type}/{hostname}/default.nix`. Global options shared across all hosts are in `hosts/shared/global/`.

## Common Workflows

- **Adding a New Host**: Create a directory for the host in the appropriate device type category and add a `default.nix`.
- **Modifying a Host**: Update the `default.nix` or associated files in the host's directory.

## References

- [Adding a New Host](../development/adding_a_new_host.md)
