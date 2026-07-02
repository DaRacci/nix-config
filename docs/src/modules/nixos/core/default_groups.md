# Groups — Shared extra group membership for all declared users

## Purpose

Provide a single `core.defaultGroups` list that other core modules and hosts use to grant access to subsystems like audio, networking, Docker, printing, and virtualisation, appended to every configured standard user.

## Entry Point

- **Main file**: [default-groups.nix](../../../../../modules/nixos/core/default-groups.nix)

## Architecture / Services / Scope

When `core.defaultGroups` is non-empty, module rewrites `users.users` entries so each declared user receives `extraGroups = mkAfter cfg.defaultGroups`.

This appends shared groups after any user-specific group configuration instead of replacing it.

## Operational Notes / Assumptions

- Module has no enable flag. It activates whenever `core.defaultGroups` contains values.
- Group assignment applies to every user passed through module argument `users`.
