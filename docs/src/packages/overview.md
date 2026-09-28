# Packages Overview

## Purpose

This section documents the custom packages defined in this repository. These are packages that are either not available in `nixpkgs` or require custom builds.

## Architecture / Services / Scope

### Entry Points

- `pkgs/`: Contains the package definitions, typically organized by package name.
  - `alvr-bin`: Binaries for ALVR that allows nvidia accelerated by using the AppImage.
  - `drive-stats`: Tool for monitoring and reporting drive statistics.
  - `colour-picker`: Hyprland color picker wrapper that temporarily lowers pointer sensitivity, launches `hyprpicker`, then restores the prior sensitivity.
  - `folder-diff`: Nushell helper that compares two directories by tracking added, modified, and deleted files in a temporary Git repo, then prints a binary-safe diff plus per-file change summaries.
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
  - `ocr-region`: Wayland OCR helper that captures selected region, preprocesses image, runs multilingual Tesseract OCR, copies detected text, and notifies result.
  - `monocoque`: Sim-racing dashboard and telemetry tool.
  - `orca-slicer-git-sync`: Watches an OrcaSlicer profile repository, commits batched changes with profile-aware commit messages, and optionally pushes to a configured remote.
  - `python`: Packages for home assistant python components.
  - `screenshot`: Wayland screenshot helper that captures an area or output, stores timestamped files, and optionally opens or annotates the result.
  - `ssh-relay`: WSL SSH agent relay helper that bridges a Windows named pipe into a local Unix socket.
  - `ssh-to-age-keys`: Converts one or more SSH private keys into a deduplicated `keys.txt` age key file.
  - `sunshine-tools`: Shared Sunshine helpers for socket-proxy startup and Hyprland monitor disable/restore hooks.
  - `swfs-mount-hooks`: Shared mount helper for `server.storage.swfsMount` prepare, stop, and health-recovery actions.
  - `take-control-viewer`: Remote support viewer for N-able Take Control via Wine.
  - `virtualisation-tools`: Shared libvirt and VFIO hook helpers for CPU isolation, GPU detach/attach, and guest hook dispatch.
  - `wait-for-io-tools`: Shared reachability and database-readiness helpers for IO Guardian-managed services.
  - `wlprop`: Wayland helper that selects a visible Hyprland window region with `slurp` and prints matching client JSON.

## Operational Notes / Assumptions

### Key Options/Knobs

Custom packages may expose different build options depending on their `derivation` definition.

### Common Workflows

- **Adding a Package**: Create a new directory in `pkgs/` with a `default.nix` file.
- **Using a Package**: Reference the package via `pkgs.<name>` if the `pkgs` overlay is active.
- **Package CI discovery**: The package build workflow enumerates package names lazily from `packages.<system>` and skips entries whose `meta.broken` evaluation fails or resolves to `true`, so one package that cannot be evaluated does not abort the entire build matrix.
