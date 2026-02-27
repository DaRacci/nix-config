# Packages Overview

## Purpose

This section documents the custom packages defined in this repository. These are packages that are either not available in `nixpkgs` or require custom builds.

## Entry Points

- `pkgs/`: Contains the package definitions, typically organized by package name.
  - `alvr-bin`: Binaries for ALVR that allows nvidia accelerated by using the AppImage.
  - `drive-stats`: Tool for monitoring and reporting drive statistics.
  - `helpers`: Collection of helper scripts for configuration management.
  - `huntress`: Integration for Huntress security agent.
  - `hypr-gamemode`: Script to optimize Hyprland performance for gaming.
  - `io-guardian`: Database lifecycle management across hosts.
  - `lidarr-plugins`: Lidarr plugins branch.
  - `list-ephemeral`: Utility to identify and list ephemeral filesystem entries.
  - `lix-woodpecker`: Woodpecker CI runner.
  - `mcp-sequential-thinking`: MCP server for step-by-step reasoning.
  - `mcp-server-amazon`: MCP server for Amazon services interaction.
  - `proton-mcp`: MCP server for ProtonMail.
  - `monocoque`: Sim-racing dashboard and telemetry tool.
  - `orca-slicer-zink`: Orca Slicer configured to use the Zink Vulkan driver to resolve nvidia rendering issues.
  - `python`: Packages for home assistant python components.
  - `take-control-viewer`: Remote support viewer for N-able Take Control via Wine.

## Key Options/Knobs

Custom packages may expose different build options depending on their `derivation` definition.

## Common Workflows

- **Adding a Package**: Create a new directory in `pkgs/` with a `default.nix` file.
- **Using a Package**: Reference the package via `pkgs.<name>` if the `pkgs` overlay is active.
