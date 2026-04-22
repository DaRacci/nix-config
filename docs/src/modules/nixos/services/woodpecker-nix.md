# Woodpecker Shared Nix Store

The `woodpeckerNix` module provides an **isolated, shared Nix store** for
Woodpecker CI pipeline containers. Instead of every pipeline step downloading
and building its dependencies from scratch, a long-lived Nix daemon manages a
persistent store on the host. Containers bind-mount that store and connect to
the daemon so they share cached derivations across jobs.

## Why an isolated store?

Running CI builds directly against the host's `/nix/store` and `nix-daemon`
has two problems:

1. **Security** – untrusted build code runs in the same store that powers your
   production system.
1. **Pollution** – CI builds leave large, unrelated closures in the host store
   and make GC harder to reason about.

The module solves both by keeping a completely separate store under
`stateDir` (default `/var/lib/woodpecker-nix`). The CI daemon, its store,
and the containers that use it are sandboxed away from the host.

## Architecture

```text
┌──────────────────────────────────────────────────────────────────┐
│  Host (NixOS)                                                    │
│                                                                  │
│  woodpecker-nix-init     ─── hash-aware bootstrap + profiles     │
│  woodpecker-nix-daemon   ─── sandboxed nix daemon                │
│       │                                                          │
│       │  bind-mount: stateDir/nix → /nix (private ns)            │
│       └──────────────────────────────────────────────────────────┤
│                                                          stateDir│
│                                                         /nix/stor│
│  Woodpecker agent  ──► Docker container                          │
│       WOODPECKER_BACKEND_DOCKER_VOLUMES =                        │
│         stateDir/nix/store            → /nix/store:ro            │
│         stateDir/nix/.../socket-dir   → /nix/var/nix/...         │
│         stateDir/nix/.../profiles     → /nix/var/nix/profiles:ro │
│         stateDir/cache/gitv3          → /root/.cache/nix/gitv3   │
│       WOODPECKER_ENVIRONMENT =                                   │
│         PATH=<runtimeEnv>/bin:/bin:/usr/bin                      │
│         NIX_REMOTE=daemon                                        │
│         SSL_CERT_FILE=<runtimeEnv>/etc/ssl/certs/ca-bundle.crt   │
└──────────────────────────────────────────────────────────────────┘
```

### systemd services

| Service                     | Purpose                                                                                                                                                                                                                                                  | Sandboxed?                                   |
| --------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------- |
| `woodpecker-nix-init`       | Hash-aware bootstrap: creates directories, copies `runtimeEnv` + `bootstrapPackages` closures into the CI store, reconstructs profile symlinks, and registers GC roots. Runs on every start — only the `nix copy` is skipped when the hash is unchanged. | No – needs host `/nix/store`                 |
| `woodpecker-nix-daemon`     | Runs `nix daemon` with the CI store bind-mounted at `/nix`                                                                                                                                                                                               | Yes – `PrivateMounts`, `ProtectSystem`, etc. |
| `woodpecker-nix-gc` (timer) | Periodic `nix-collect-garbage` against the CI store                                                                                                                                                                                                      | No                                           |

## How version-drift is handled

### The problem

CI Docker images built with `nix2container` (like `lix-woodpecker`) bake
their runtime packages into image layers as `/nix/store/…` paths. The module
bind-mounts the CI store over `/nix/store` inside every container — which
**replaces** the image's store entirely. If the image was built at a different
time than the host (different nixpkgs revision, different Lix version, etc.),
the store hashes diverge and the container's own packages vanish:

```text
exec: "/bin/sh": stat /bin/sh: no such file or directory
```

Even when the container manages to start (via a static `/bin/sh`), the Nix
profile symlink chain inside the image breaks:

```text
/root/.nix-profile → /nix/var/nix/profiles/default
  → /nix/var/nix/profiles/default-1-link
    → /nix/store/<image-hash>-user-environment   ← MISSING from CI store
```

This leaves the shell with no tools besides builtins, `sh`, and `env`.

### The solution — three complementary mechanisms

1. **Static `/bin/sh`** — The `lix-woodpecker` image includes a layer with
   a statically-linked [BusyBox](https://busybox.net/) binary at `/bin/sh`
   and `/usr/bin/env`. These are real files (not symlinks into `/nix/store`),
   so they survive the store overlay and let the OCI runtime exec the
   container regardless of what is in the CI store.

1. **`runtimePackages` + PATH injection** — The module builds a merged
   `buildEnv` ("runtimeEnv") from the host's current packages and injects
   `PATH=<runtimeEnv>/bin:/bin:/usr/bin` into every pipeline container via
   `WOODPECKER_ENVIRONMENT`. This completely decouples the container's
   runtime tools from the image's own `/nix/store` paths:
   - The tools (nix, git, jq, …) always match the **host's** store.
   - The `runtimeEnv` closure is copied into the CI store during bootstrap.
   - Version drift between image and host never causes missing-binary failures.

1. **Profile symlink reconstruction** — The init service rebuilds the Nix
   profile chain inside the CI store's profile directory and mounts it into
   containers at `/nix/var/nix/profiles:ro`. This ensures the image's
   default PATH entries (`/root/.nix-profile/bin`,
   `/nix/var/nix/profiles/default/bin`) also resolve correctly:

   ```text
   stateDir/nix/var/nix/profiles/default-1-link → <runtimeEnv>     (in CI store)
   stateDir/nix/var/nix/profiles/default        → default-1-link
   ```

   The profile reconstruction runs on **every** init service start (not just
   when the bootstrap hash changes), so even manually-deleted symlinks are
   repaired automatically. A GC root is also registered so the runtime
   environment survives garbage collection.

### Hash-aware bootstrap

The init service computes a SHA-256 hash of the store paths of the
`runtimeEnv` and every `bootstrapPackages` entry. It writes this to
`<stateDir>/.bootstrap-hash`. On every service start it compares the recorded
hash against the current one:

- **Unchanged** → skips `nix copy` (no copy overhead), still verifies profiles.
- **Changed** (e.g. after `nix flake update`) → runs `nix copy` for each
  package and updates the hash file.

You never need to clear a sentinel file manually; updates are picked up
automatically on the next host rebuild + restart.

## Basic configuration

```nix
services.woodpeckerNix = {
  enable = true;

  isolatedStore.enable = true;

  # Tools available to every CI container via PATH.
  # Defaults include bash, coreutils, git, cacert, curl, etc.
  # Add project-specific tools here:
  isolatedStore.runtimePackages = with pkgs; [
    bashInteractive
    coreutils-full
    cacert
    gitMinimal
    gnutar
    gzip
    gnugrep
    findutils
    curl
    # Project extras:
    gawk
    jq
    gnupg
    attic-client
    openssh
    which
    less
  ];

  # Apply store + daemon socket volumes to these Woodpecker agents.
  woodpecker.agents = [ "local" ];
};
```

> **Note:** `isolatedStore.package` (the Nix/Lix daemon, defaulting to
> `config.nix.package`) is always included in the runtime environment
> automatically — you do not need to list it in `runtimePackages`.

## Cache options

The `cache` option controls what Nix caches are shared across pipeline
containers. It is a single enum with three values:

### `"none"`

Don't share any caches. Each pipeline starts cold. This is the safest option
but slowest.

### `"git"` (default)

Mounts `<stateDir>/cache/gitv3` at `/root/.cache/nix/gitv3` inside every
container. Git pack files use atomic writes, so concurrent jobs share the
cache safely. This eliminates repeated `git fetch` operations and pack
unpacking on every job.

### `"all"`

Mounts `<stateDir>/cache` at `/root/.cache/nix` inside every container,
sharing the entire Nix cache directory (including the eval cache).

> **Warning:** the eval cache is a SQLite database. SQLite supports many
> concurrent _readers_ but only a single _writer_ at a time. Enabling this
> option with high-parallelism agents can cause lock contention and stale
> reads. Only enable it when you know builds are effectively sequential
> (e.g. `WOODPECKER_MAX_WORKFLOWS=1`) or when contention is acceptable.

## Reference

### Options

{{#include ../../../generated/woodpecker-nix-options.md}}

### Injected container environment

When `isolatedStore.enable` is true, the module automatically injects the
following into every pipeline container:

| Variable            | Value                                      | Purpose                                            |
| ------------------- | ------------------------------------------ | -------------------------------------------------- |
| `PATH`              | `<runtimeEnv>/bin:/bin:/usr/bin`           | Tools from the CI store + static busybox fallback  |
| `NIX_REMOTE`        | `daemon`                                   | Route all Nix operations through the shared daemon |
| `SSL_CERT_FILE`     | `<runtimeEnv>/etc/ssl/certs/ca-bundle.crt` | TLS certificate bundle                             |
| `NIX_SSL_CERT_FILE` | (same as above)                            | Nix-specific TLS certs                             |
| `GIT_SSL_CAINFO`    | (same as above)                            | Git TLS certs                                      |

### Injected container volumes

| Host path                              | Container path               | Mode | Purpose                           |
| -------------------------------------- | ---------------------------- | ---- | --------------------------------- |
| `<stateDir>/nix/store`                 | `/nix/store`                 | `ro` | Shared Nix store                  |
| `<stateDir>/nix/var/nix/daemon-socket` | `/nix/var/nix/daemon-socket` | `rw` | Daemon socket                     |
| `<stateDir>/nix/var/nix/profiles`      | `/nix/var/nix/profiles`      | `ro` | Reconstructed profile symlinks    |
| `<stateDir>/cache/gitv3`               | `/root/.cache/nix/gitv3`     | `rw` | Git cache (when `cache = "git"`)  |
| `<stateDir>/cache`                     | `/root/.cache/nix`           | `rw` | Full cache (when `cache = "all"`) |

## Troubleshooting

### Container fails with `no such file or directory` for `/bin/sh`

The container image's `/bin/sh` is a symlink into `/nix/store` which has been
replaced by the CI store mount. Ensure the `lix-woodpecker` image includes
the static shell layer (`staticShellLayer = true` in
`pkgs/lix-woodpecker/default.nix`). The layer provides a real,
statically-linked `/bin/sh` binary that survives the overlay.

### Tools missing or wrong version in CI steps

All tools come from `isolatedStore.runtimePackages` (via PATH), **not** from
the Docker image. If a tool is missing, add it to
`isolatedStore.runtimePackages` in the host config and rebuild. The init
service will detect the hash change and re-copy closures automatically.

If tools are still missing after adding them, check the agent's
`WOODPECKER_ENVIRONMENT` is being set correctly — it should contain
comma-separated `KEY=VALUE` pairs including `PATH=...`.

### Profile symlinks broken

The init service reconstructs profile symlinks on every start. If profiles
appear broken:

1. Check that `<stateDir>/nix/var/nix/profiles` is mounted into the container
   (verify agent `WOODPECKER_BACKEND_DOCKER_VOLUMES`).

1. Inspect the host-side symlinks:

   ```bash
   ls -la /var/lib/woodpecker-nix/nix/var/nix/profiles/
   ```

   You should see `default-1-link` pointing to a `/nix/store/...-woodpecker-ci-runtime`
   path, and `default` pointing to `default-1-link`.

1. Restart the init service to force reconstruction:

   ```bash
   systemctl restart woodpecker-nix-init.service
   ```

### Bootstrap is slow after a `nix flake update`

This is expected: `nix copy` transfers potentially large closures into the CI
store. Subsequent starts are instant (hash unchanged → skip copy, still verify
profiles). Enable a binary cache substituter (via
`isolatedStore.substituters` / `isolatedStore.trustedPublicKeys`) to speed up
the initial copy.

### Daemon socket permission denied

Check that the Woodpecker agent user is in the `docker` group (for the Docker
backend) and that `<stateDir>/nix/var/nix/daemon-socket` has mode `1777`. The
init service sets this on every start; check its journal if permissions look
wrong:

```bash
journalctl -u woodpecker-nix-init.service
```

### Forcing a full re-bootstrap

Delete the hash sentinel and restart the init service:

```bash
rm /var/lib/woodpecker-nix/.bootstrap-hash
systemctl restart woodpecker-nix-init.service
```

### Verifying the fix end-to-end

After deploying, run a test pipeline that exercises the full chain:

```yaml
steps:
  - name: verify
    image: registry.racci.dev/lix-woodpecker:latest
    commands:
      - echo "Shell: $(which sh)"
      - echo "PATH: $PATH"
      - nix --version
      - git --version
      - ls -la /nix/var/nix/profiles/default
      - readlink -f /nix/var/nix/profiles/default
```

All commands should succeed. The `readlink` should resolve to a
`/nix/store/...-woodpecker-ci-runtime` path that exists in the mounted store.
