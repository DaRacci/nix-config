# Core Module

Documents shared NixOS core modules used across hosts.

## Purpose

`modules/nixos/core/` contains reusable host-level defaults and feature modules such as display management, remote access, OpenSSH, locale, security, and virtualisation.

## Key Pages

- [Display Manager](display_manager.md)
- [Remote Access](remote.md)
- [Virtualisation](virtualisation.md)

## Notes

These modules are imported through `modules/nixos/core/default.nix` and expose options under the `core.*` namespace.
