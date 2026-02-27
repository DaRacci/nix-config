# Lib Overview

## Purpose

The `lib` directory contains custom Nix functions and builders used throughout the repository to simplify configuration and reduce duplication.

## Entry Points

- `lib/`: Root directory for lib functions.
  - `attrsets.nix`: Functions for manipulating and merging attribute sets.
  - `default.nix`: Main entry point providing the `mine` and `builders` namespaces.
  - `files.nix`: Utilities for filesystem operations and path handling.
  - `hardware.nix`: Detection and configuration helpers for hardware acceleration and drivers.
  - `hypr.nix`: Specialized helpers for Hyprland window manager configurations.
  - `keys.nix`: Management of SSH, GPG, and other cryptographic keys.
  - `package.nix`: Custom package definitions and derivation helpers.
  - `persistence.nix`: Helpers for managing path persistence in ephemeral (TempFS) environments.
  - `strings.nix`: String manipulation and formatting utilities.
- `lib/builders/`: Contains specialized builders for system and home configurations.

## Key Options/Knobs

The functions in `lib` take various arguments depending on their purpose. Builders typically take parameters for hostnames, user names, and modules.

## Common Workflows

- **Using a Lib Function**: Access functions via `outputs.lib.<functionName>` or by importing the relevant file.
- **Creating a Builder**: Add new builder logic to `lib/builders/`.
