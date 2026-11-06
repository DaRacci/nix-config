# Tests

Tests live under `tests/`, with `tests/default.nix` as the registry.
Add an entry there to expose a test through the flake.

Tests are exposed as the `tests.<system>.<name>` flake output.
`nix flake check` reports it as an unknown flake output; that warning is expected for a custom output outside the standard flake schema.
They are deliberately outside `checks` and `packages`, so the CI discovery matrices do not pick them up.
Run them explicitly, or wire a dedicated CI step when they should gate a change.

## Running Tests

Build one test by its flake output:

```bash
nix build .#tests.x86_64-linux.woodpecker-store
```

The `run-tests` helper is available in the development shell and through `nix run`.
It defaults to the current system:

```bash
run-tests --list
run-tests woodpecker-store
run-tests --all
run-tests --system aarch64-linux --list
```

With `nix run`, separate the helper arguments from `nix run` arguments with `--`:

```bash
nix run .#run-tests -- --all
```

## Adding a Test

1. Add the test expression under `tests/`, for example `tests/vm/my-service.nix`.
1. Import it in `tests/default.nix` under the name it should use in the flake output.
1. Run `nix fmt .` and `run-tests my-service`.

VM tests use `pkgs.testers.runNixOSTest` and keep `vm-` in the test name, so the build log and store path identify it as a VM test.
See [VM Tests](vm_tests.md) for the current VM test coverage.
