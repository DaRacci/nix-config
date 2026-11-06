# Continuous Integration

Pipelines live in `.woodpecker/` and run on the self-hosted Woodpecker instance.
The Nix steps run in the `registry.racci.dev/lix-woodpecker:latest` image, which enables the `pipe-operators` experimental feature.

## Check Pipeline

`check.yaml` runs on every push and pull request that targets `master`.
It has three steps:

1. `Evaluate home configurations` evaluates `.#homeConfigurations` and the `activationPackage.drvPath` of every attribute.
1. `Build flake checks` builds `checks.<system>` through `nix-fast-build`.
1. `Run flake checks` runs `nix flake check`.

## Other Pipelines

- `docs-lint.yaml` lints documentation when a documentation path changes.
- `check-upstream-todos.yaml` checks comments that link to upstream pull requests or issues.
- `flake-checker.yaml` validates the flake inputs and outputs.
- `security.yaml` scans pushed commits for secrets.
- `update.yaml` updates the flake locks and opens a pull request.
- `lix.yaml` builds and publishes the CI image when its inputs change.
