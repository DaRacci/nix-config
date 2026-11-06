# Woodpecker CI

CI runs on the self-hosted Woodpecker instance on `nixdev`.
Woodpecker is attached to the Codeberg repository; the GitHub forge is
intentionally disabled while GitHub is being phased out.
The GitHub workflows that remain are only the Codeberg mirror and GitHub Pages
deployment.

## Pipelines

| File | Purpose | Triggers |
| --- | --- | --- |
| `affected.yaml` | Compute affected hosts, homes, and packages once per pipeline | pull requests, `master` pushes, manual |
| `checks.yaml` | Flake checks, flake-checker, upstream `check-upstream-todos` checks, secret scan, matrix refresh | pull requests, `master` pushes, weekly cron, manual |
| `ci-hosts.yaml` | Build affected NixOS hosts, then run `vulnix` | pull requests, `master` pushes, manual |
| `ci-homes.yaml` | Build affected Home Manager configurations | pull requests, `master` pushes, manual |
| `ci-packages.yaml` | Build affected packages on `x86_64-linux` | pull requests, `master` pushes, manual |
| `docs-lint.yaml` | Vale and `rumdl` | Docs-related pull requests and `master` pushes, manual |
| `update-packages.yaml` | Run package `updateScript`s and open pull requests | `update-packages` cron, manual |
| `update.yaml` | Update all `flake.lock` files and open one PR | `update-flake-inputs` cron, manual |
| `lix.yaml` | Publish the `lix-woodpecker` image | `master` pushes touching `flake.lock` or `pkgs/lix-woodpecker/` |

The `affected` workflow runs the graph and package discovery once per pipeline and writes JSON lists to the shared `/ci-cache` volume.
The build workflows depend on it and only read those lists, so Woodpecker's per-matrix execution does not repeat the expensive detection.

## Required secrets

Configure these in the Woodpecker repository settings:

| Secret | Used by |
| --- | --- |
| `BINARY_CACHE_TOKEN` | Attic cache setup in build pipelines |
| `FORGE_TOKEN` | `create-pr` (Codeberg API token) |
| `FORGE_AUTH_KEY` | Branch pushes to Codeberg over SSH |
| `GITGUARDIAN_API_KEY` | Secret scanning |
| `GITHUB_TOKEN` | Fetching GitHub-hosted flake inputs during lock updates |
| `GPG_PRIVATE_KEY`, `GPG_FINGERPRINT`, `GPG_PASSPHRASE` | Signed lock-update commits |
| `REGISTRY_USER`, `REGISTRY_TOKEN` | Publishing the `lix-woodpecker` image |

## Crons

Woodpecker crons are configured in the UI, not in the repository:

| Name | Used by |
| --- | --- |
| `weekly` | `check-upstream-todos`, `run-flake-checker` |
| `update-packages` | `update-packages.yaml` |
| `update-flake-inputs` | `update.yaml` |

## Matrices

The host, home, package, and update matrices are committed to their pipeline files and refreshed by `checks.yaml` with:

```sh
nix run .#update-matrix -- <file> <key> <flake-output>
```

The updater only rewrites the matrix key's lines, so comments and the rest of the file are preserved.
`update-packages.yaml` is filtered to packages with a `passthru.updateScript` and `passthru.discovery` not set to `false`.

## Packages are x86_64 only

Package builds use the amd64 agent.
There are no aarch64 hosts to attach an arm agent to, so `aarch64-linux` package builds are not run.

CI helper applications are marked `passthru.ci = false` and excluded from the package build matrix.
This keeps the matrix under Woodpecker's limit of 64 workflows.
Real packages with `passthru.discovery = false` are still built.
