# Packages Overview

## Purpose

This section documents the custom packages defined in this repository. These are packages that are either not available in `nixpkgs` or require custom builds.

## Architecture / Services / Scope

### Entry Points

- `pkgs/`: Contains the package definitions, typically organized by package name.
  - `alvr-bin`: Binaries for ALVR that allows nvidia accelerated by using the AppImage.
  - `drive-stats`: Tool for monitoring and reporting drive statistics.
  - `helpers`: Collection of helper scripts for configuration management.
  - `huntress`: Integration for Huntress security agent.
  - `hypr-gamemode`: Script to optimize Hyprland performance for gaming.
  - `io-guardian`: Database lifecycle management across hosts.
  - `lidarr-plugins`: Lidarr plugins branch.
  - `list-ephemeral`: Utility to identify ephemeral paths, trace file access, and generate persistence snippets.
  - `lix-woodpecker`: Woodpecker CI runner.
  - `mcp-sequential-thinking`: MCP server for step-by-step reasoning.
  - `mcp-server-amazon`: MCP server for Amazon services interaction.
  - `proton-mcp`: MCP server for ProtonMail.
  - `compressor`: Python tool that hashes image/video files, detects media from magic headers, caches WebP image conversions and AV1 MP4 video conversions. For videos, it samples 3 random segments to estimate compression ratio and auto-skip expansion cases. Those sample encodes now use live HandBrake JSON progress too, with per-sample ETA plus total sample ETA in Rich progress bars. Full sequential video encodes also parse live JSON progress, update Rich progress bars with per-video ETA plus rolling queue ETA, fall back to elapsed/progress-derived ETA when HandBrake reports zero, and `--debug` prints periodic runtime progress snapshots. Records applied outputs in its TSV cache and prints aligned Rich tables.
  - `monocoque`: Sim-racing dashboard and telemetry tool.
  - `orca-slicer-zink`: Orca Slicer configured to use the Zink Vulkan driver to resolve nvidia rendering issues.
  - `python`: Packages for home assistant python components.
  - `take-control-viewer`: Remote support viewer for N-able Take Control via Wine.

## Operational Notes / Assumptions

### Key Options/Knobs

Custom packages may expose different build options depending on their `derivation` definition.

### Common Workflows

- **Adding a Package**: Create a new directory in `pkgs/` with a `default.nix` file.
- **Using a Package**: Reference the package via `pkgs.<name>` if the `pkgs` overlay is active.
