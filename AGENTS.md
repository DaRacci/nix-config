# Repository Guidelines

This document is a quick reference for contributors working on the
Nix‑based configuration repository. Follow the sections below when you
add or adjust files to keep the repo consistent, buildable, and clear to
others.

## Project Structure & Module Organization

- **flake.nix / flake.lock** – top‑level flake definitions. All external
  input is pulled here.
- **modules/** – reusable NixOS / Home‑Manager module fragments.
- **hosts/** – per‑machine configurations split into sub groups (desktop, laptop, server).
- **home/** – user‑specific Home‑Manager declarations.
- **utils/** – helper functions and scripts.
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

**Note:** This repository uses `devenv` for devShells and checks. You must provide the `devenv-root` input override for all calls to `nix flake check` and `nix develop`. This is done by adding the following argument to these commands.


```
--override-input devenv-root "file+file://$PWD/.devenv/root"
```

Without this override, pure flake evaluation will fail with a directory error. For CI or non-interactive environments, ensure the override is set or use impure mode if appropriate.

## Coding Style & Naming Conventions

- **Indentation**: 2 spaces for Nix expressions. No tabs allowed.
- **File names**: lowercase, hyphen‑separated (e.g., `my‑service.nix`).
- **Module keys**: follow `services.<name>.<subkey>` pattern.
- **Imports**: prefer relative imports (`./modules/*.nix`).
- **Linting**: run `nix flake check` before each PR; it runs Hydra checks.

## Testing Guidelines

- Run `nix fmt` after all changes to ensure consistent formatting.
- Use `nix flake check` to evaluate and check all configurations.

## Commit & Pull Request Guidelines

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
- If UI‑related, add screenshots under `docs/`.
- Ensure `nix flake check` passes locally and CI.
- Run `nix fmt` for formatting.
