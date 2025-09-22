# Repository Guidelines for Agents

This document is a quick reference for contributors working on the
Nix‑based configuration repository. Follow the sections below when you
add or adjust files to keep the repo consistent, buildable, and clear to
others.

If something has been labeled as a "MUST" you are required to follow its instructions at all times when working on this repository.

## Project Structure & Module Organization

- **flake.nix** – top‑level flake definitions.
  - **flake/dev/** - flake and resources for development and CI.
- **modules/** – reusable module fragments.
  - **home-manager/** – Home‑Manager specific modules.
  - **nixos/** – NixOS specific modules.
- **lib/** – shared Nix functions / helpers.
- **overlays/** – Nixpkgs overlays.
- **pkgs/** - custom packages and package sets.
- **hosts/** – per‑machine configurations split into sub groups.
  - **shared/** – shared declarations across all machines.
  - **\<group\>/** - group of similar machines (e.g., `desktop`, `laptop`, `server`).
    - **\<machine\>/** – machine‑specific NixOS declarations.
    - **shared/** - group‑wide shared declarations.
- **home/** – user‑specific Home‑Manager declarations.
  - **shared/** – shared declarations across all users.
  - **\<user\>/** – user‑specific Home‑Manager declarations.
    - **\<machine>.nix** - machine-specific overrides for the user.
    - **os-config.nix** - Additional OS Configuration for the user applied to all machines it is used on.
  - **shared/** – shared declarations across all users.
- **docs/** – project documentation. Add new sections next to `README.md`.

## Build, Test, and Development Commands

| Command | What It Does |
|---------|--------------|
| `nix build .#nixosConfigurations.<host>.config.system.build.toplevel` | Builds the host’s NixOS system |
| `nix build .#homeConfigurations.<user>.activationPackage` | Builds a Home‑Manager activation |
| `nix fmt` | Lints the flake and checks for syntax errors |
| `nix flake check` | Evaluates all configurations and runs linters |
| `nix flake show` | Displays available outputs and inputs |
| `nix develop` | Opens a development shell |
| `nix develop --command true` | Tests that the devShell can be entered correctly |

**Note:** This repository uses `devenv` for devShells and checks. You must provide the `devenv-root` input override for all calls to `nix flake check` and `nix develop`. This is done by adding the following argument to these commands.

```
--override-input devenv-root "file+file://$PWD/.devenv/root"
```

## Coding Style & Naming Conventions

- **Indentation**: 2 spaces, No tabs allowed.

- **Naming**: Use kebab-case for files and directories, camelCase for Nix Attributes.

- **Comments**: Minimal comments, prefer self-explanatory code. Use comments to explain *why* something is done, not *what* is being done.

- **Imports**: prefer relative imports (`./modules/*.nix`); Group imports at the top of the file.

- **Linting**: you MUST run `nix fmt <paths...>` after making any changes to ensure consistent formatting.

- **YAML/JSON/other structured strings**: When you need to generate configuration files or strings in formats like JSON or YAML, prefer defining the data as a Nix attribute set and using a converter such as `builtins.toJSON` (for JSON) to produce the string.

## Testing Guidelines

After making changes you **MUST ALWAYS** evaluate and test your changes.

Get an overview of what nix files are used on each host or home configuration by running the script `./flake/dev/scripts/module-graph.nu`.
This outputs a json array of objects with the following structure:

```json
{
  "file": "<path/to/file>",
  "hosts": [ "<host1>", "<host2>" ],
  "homes": [ "<user1>", "<user2>" ]
}
```

Based on the output, determine which machines or home configurations are affected by your changes and test at-least one of each type affected, these commands are documented in the [Build, Test, and Development Commands](#build-test-and-development-commands) section.

## Commit & Pull Request Guidelines

Before submitting changes to the repository ensure that you have:

- Run `nix fmt` to format the code.
- Run `nix flake check` to ensure that all configurations evaluate correctly.
- Tested at-least one host and one home configuration affected by your change.
- Verified that your commit messages and pull request titles follow the guidelines below.

### Commit Messages

Follow the conventional format seen in the history:

```
type(scope): brief summary

Optional body
```

Types: `feat`, `fix`, `chore`, `refactor`, `build`, `ci`, `style`.
Scope the common directory eg: `home/<user>`, `hosts/server`, `hosts/server/<machine>`.

### Pull Requests

- Title mirrors the commit header.
- Link issues with `Closes #123` or `Fixes #123`.
- Ensure `nix flake check` passes locally and CI.
- Run `nix fmt` for formatting.
- Describe changes and reasoning in the PR description.
