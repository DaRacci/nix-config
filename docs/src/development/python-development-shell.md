# Python Development Shell

This repository contains multiple Python scripts and packages.
A dedicated Python development environment is provided via devenv to simplify development of these components, by providing all necessary dependencies for proper LSP support.

## Entering the Python Shell

To access the Python development environment with all required dependencies:

```bash
direnv allow
devenv shell python
```

Or with devenv directly:

```bash
devenv shell --file devenv.nix --shell python
```

## Included Packages

The Python shell inherits from the default development environment and adds:

### Python Runtime & Tools
- **python312** - Python 3.12 interpreter
- **pip** - Package installer
- **virtualenv** - Virtual environment management
- **pytest** - Testing framework
- **black** - Code formatter
- **ruff** - Fast Python linter
- **mypy** - Static type checker

### Python Libraries

Libraries are organized by the components they support:

#### Image Compression
- `pillow` - Image processing
- `rich` - Terminal formatting & progress bars
- `python-magic` - File type detection

#### Memory/Knowledge Systems
- `pyyaml` - YAML parsing
- `cryptography` - Encryption utilities
- `anyio` - Async I/O framework

#### I/O Guardian & Networking
- `websockets` - WebSocket protocol
- `pystemd` - Systemd D-Bus interface

#### Utilities
- `requests` - HTTP library (for Lidarr plugin updates)

## Development Workflow

### Testing Scripts

Run pytest on project Python files:

```bash
pytest pkgs/scripts/test_image_compressor.py -v
```

### Code Quality

Format Python code:

```bash
black pkgs/scripts/image-compressor.py
```

Check with ruff:

```bash
ruff check pkgs/scripts/ pkgs/python/ docs/preprocessor/
```

Check types with mypy:

```bash
mypy pkgs/scripts/
```

### Running Scripts Directly

Scripts can be executed directly in the shell:

```bash
python3 pkgs/scripts/image-compressor.py --help
python3 docs/preprocessor/gen-options-md.py --help
```

## Adding New Python Dependencies

To add a new Python library:

1. Identify the `python312Packages.` attribute in nixpkgs
2. Add it to the `packages` list in `/persist/nix-config/flake/dev/devenv.nix` under `devenv.shells.python`
3. Run `nix fmt flake/dev/devenv.nix` to format
4. Test with `nix flake check`
5. Update this documentation

Example:

```nix
# In devenv.nix, add to packages list:
python312Packages.your-new-package
```

## Troubleshooting

### ModuleNotFoundError

If you see `ModuleNotFoundError: No module named 'xxx'`, the package may not be in the python shell. Verify it's included in the packages list in `flake/dev/devenv.nix`.

### Python Version Mismatch

Some packages require Python 3.12. If you need a different version:

1. Modify `python312` reference in `flake/dev/devenv.nix`
2. Update corresponding `python312Packages` references
3. Run `nix flake check` to validate

### Permissions Errors with pystemd

The `pystemd` package requires D-Bus access. Ensure you're running within a proper devenv session, not in a sandboxed environment.

## See Also

- [Main development documentation](../src/development/)
- [Nix Python packaging](https://nixos.org/manual/nixpkgs/stable/#chap-python)
- [Devenv documentation](https://devenv.sh/)
