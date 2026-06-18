# Firecrawl

Generic Firecrawl service wrapper with hardened systemd sandboxing.

- **Entry point**: `modules/nixos/services/firecrawl.nix`
- **Package**: `pkgs.firecrawl`

## Package

Firecrawl is **built from source** via `pkgs/firecrawl/default.nix` — no Docker image involved. The build compiles three languages:

- **Go** — builds `libhtml-to-markdown.so` (shared library, FFI-loaded by Node.js via `koffi`)
- **Rust** — builds the `firecrawl-rs` napi-rs native addon (cdylib, loaded as `firecrawl-rs.linux-x64-gnu.node` with a generated `index.js` loader)
- **TypeScript** — the main application server, compiled via `pnpm run build` from `apps/api/`

### Build Dependencies

| Language   | Toolchain                                | Output                                                       |
| ---------- | ---------------------------------------- | ------------------------------------------------------------ |
| Go         | `go`                                     | `sharedLibs/go-html-to-md/libhtml-to-markdown.so`            |
| Rust       | `rustPlatform` (`fetchCargoVendor`)      | `native/firecrawl-rs.linux-x64-gnu.node` + `native/index.js` |
| TypeScript | `nodejs_22`, `pnpm_10` (`fetchPnpmDeps`) | `dist/`, `node_modules/`                                     |

### Runtime Closure

The package produces a wrapper at `bin/firecrawl` that runs:

```
FIRECRAWL_DISABLE_CONTAINER_MANAGEMENT=1 \
node dist/src/harness.js --start-docker
```

The wrapper sets `FIRECRAWL_DISABLE_CONTAINER_MANAGEMENT=1` to bypass
upstream container management, letting Firecrawl run natively on NixOS
without Docker / Podman or a fake RabbitMQ URL.

The runtime output (`$out/lib/firecrawl/`) contains:

- `dist/` — compiled TypeScript
- `node_modules/` — pruned production dependencies
- `native/` — Rust napi addon (`.node` + `index.js` loader)
- `sharedLibs/go-html-to-md/` — Go shared library (`.so`)
- `package.json`, `pnpm-lock.yaml`

### FoundationDB

FoundationDB is **optional**. Firecrawl's default queue backend uses PostgreSQL, so FDB is not required. This build does not include FoundationDB.

### Playwright

The package wrapper exports Nix-managed Playwright browser environment
variables (`PLAYWRIGHT_BROWSERS_PATH`, `PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1`)
for direct use via `nix run .#firecrawl`. The package itself does not
bundle browser binaries — Playwright is a **separate service dependency**.

For systemd service overrides, see [Playwright Browsers](#playwright-browsers) below.
The module option `services.firecrawl.playwright.browsersPath` can be set
to `null` to let Playwright manage its own browsers.

### Availability

- **Visibility**: private to this repository
- **Platforms**: `x86_64-linux` only — the Rust napi-rs build targets `linux-x64-gnu` and does not include `aarch64-linux`

## Special Options

{{#include ../../../../generated/services-firecrawl-options.md}}

## Auth Model

The Firecrawl server **does not enforce request auth** from any env var. The `FIRECRAWL_API_KEY` secret belongs to **client consumers** (Hermes, ai-agent) that need it to authenticate their Firecrawl API calls.

For public exposure, use **Kanidm OAuth2 at the reverse proxy layer**. The proxy module supports:

- `server.proxy.virtualHosts.<name>.public = true` — exposes via Cloudflare Tunnel
- `server.proxy.virtualHosts.<name>.kanidm.allowGroups` — restricts access to Kanidm groups
- The OAuth2 client secret is stored in `secrets.yaml` as `KANIDM/OAUTH2/FIRECRAWL_SECRET`

There is **no unsecured public endpoint**. All external requests go through Kanidm authentication before reaching the Firecrawl backend.

## Smoke Test

Ad-hoc validation helper that starts temporary PostgreSQL (with NUQ schema loaded),
Redis, RabbitMQ, an HTTP fixture, and the full `firecrawl` harness on high ports.
Performs liveness/readiness checks and real `POST /v1/scrape` and `POST /v2/scrape`
requests against the local fixture, asserting the scraped markdown contains the expected
fixture text. Also validates that unauthenticated / bogus-key requests succeed (auth is
not enforced server-side):

```bash
nix run .#firecrawl-smoke-test
```

### Infrastructure

| Service    | Role                                 |
| ---------- | ------------------------------------ |
| PostgreSQL | Main DB + NUQ queue tables           |
| Redis      | Queue locking / rate limiting        |
| RabbitMQ   | NUQ prefetch + job listener exchange |
| HTTP       | Local fixture page to scrape         |

### Key env vars set by the test

| Variable                 | Purpose                       |
| ------------------------ | ----------------------------- |
| `DATABASE_URL`           | Postgres connection           |
| `NUQ_DATABASE_URL`       | Same as `DATABASE_URL`        |
| `REDIS_URL`              | Queue Redis                   |
| `REDIS_RATE_LIMIT_URL`   | Rate-limit Redis              |
| `NUQ_RABBITMQ_URL`       | RabbitMQ for NUQ              |
| `TEST_SUITE_SELF_HOSTED` | Accept localhost URLs         |
| `ALLOW_LOCAL_WEBHOOKS`   | Allow local webhook listeners |
| `USE_DB_AUTHENTICATION`  | Skip public-schema auth       |
| `DISABLE_BLOCKLIST`      | Accept any URL                |

### NUQ schema loading

The NUQ PostgreSQL schema is loaded from `${firecrawl}/share/firecrawl/nuq.sql`.
Lines that require `pg_cron` (`CREATE EXTENSION pg_cron`, `SELECT cron.schedule(...)`)
and `ALTER SYSTEM` tuning directives are filtered out — these need
`shared_preload_libraries` and global config not available on a transient instance.

### Validation sequence

1. Start PostgreSQL, load NUQ schema
1. Start Redis
1. Start RabbitMQ with `guest:guest@127.0.0.1:<port>`
1. Start Python HTTP server serving a fixture page with known text
1. Start packaged `firecrawl` binary (full harness) with all env vars above
1. Wait for `/v0/health/liveness` → `{"status":"ok"}`
1. Wait for `/v0/health/readiness` → `{"status":"ok"}`
1. `POST /v1/scrape` with fixture URL, `formats:["markdown"]`
1. `POST /v2/scrape` with same fixture URL, `formats:["markdown"]`
1. `POST /v2/scrape` without auth header, assert `success=true`
1. `POST /v2/scrape` with `Authorization: Bearer fake-key-12345`, assert `success=true`
1. Assert `success=true` and markdown contains `Hello from Firecrawl smoke test`
1. Cleanup all processes and temp directory

Exits zero on pass, non-zero with diagnostic output on failure.

## Secrets Management

Prefer sops-nix for API key handling. `nixai` declares:

- `FIRECRAWL/API_KEY` — for client consumers (ai-agent, Hermes) to authenticate Firecrawl API calls
- `FIRECRAWL/BULL_AUTH_KEY` — for Firecrawl queue admin UI
- `REDIS/PASSWORD` — required when using repo-managed Redis
- `KANIDM/OAUTH2/FIRECRAWL_SECRET` — Kanidm OAuth2 client secret for proxy-layer auth
- `AI_AGENT/OPENROUTER_API_KEY` — shared OpenRouter API key (reused by Firecrawl via `openrouter.apiKeyFile`)

## Default Setup (local-only, repo DB stack)

```nix
{ config, ... }: let
  inherit (config.sops) placeholder;
in {
  sops.secrets = {
    "FIRECRAWL/API_KEY" = { };
    "FIRECRAWL/BULL_AUTH_KEY" = { };
  };

  server.database.postgres.firecrawl = { };
  server.database.redis = {
    firecrawl = { };
    firecrawl-rate-limit = { };
  };
  server.database.dependentServices = [ "firecrawl" ];

  services.firecrawl = {
    enable = true;
    host = "127.0.0.1";
    openFirewall = false;
    bullAuthKeyFile = config.sops.secrets."FIRECRAWL/BULL_AUTH_KEY".path;
    # redisUrl, redisRateLimitUrl, databaseUrl all left null —
    # module derives them from server.database.redis.* and server.database.postgres.firecrawl
  };
}
```

Setting `redisUrl` or `redisRateLimitUrl` manually is only needed when the module's auto-derived defaults are incorrect (e.g., non-standard auth). Prefer declaring `server.database.redis.firecrawl` and `server.database.redis.firecrawl-rate-limit` instead, which lets the IO host assign correct DB IDs.

Firecrawl looks up `DATABASE_URL` from its config on disk; declare `server.database.postgres.firecrawl` so the IO Host provisions the role and database.

### Public Exposure Pattern

```nix
server.proxy.virtualHosts.firecrawl = {
  ports = [ config.services.firecrawl.port ];
  public = true;
  kanidm = {
    allowGroups = [ "cloud@auth.racci.dev" ];
  };
  extraConfig = ''
    reverse_proxy http://${config.services.firecrawl.host}:${toString config.services.firecrawl.port}
  '';
};
```

- `public = true` — exposes via Cloudflare Tunnel (no raw public firewall port)
- `kanidm.allowGroups` — restricts access to members of `cloud@auth.racci.dev`
- Reverse proxy targets localhost (`127.0.0.1:3002`) — Firecrawl itself never binds publicly
- The OAuth2 client secret is provisioned by the repo's `kanidm.nix` extension module from `KANIDM/OAUTH2/FIRECRAWL_SECRET`

### Local Consumer Access

The `FIRECRAWL/API_KEY` secret is declared but consumed by `ai-agent` (not the Firecrawl server process). Consumers connect to `http://127.0.0.1:3002` directly on the loopback interface.

PostgreSQL (`firecrawl` database + role) and Redis (DB IDs 1 and 2 for `firecrawl` / `firecrawl-rate-limit`) are declared via `server.database.postgres.firecrawl` and `server.database.redis`. The service is registered in `database.dependentServices` so the IO Guardian waits for databases before starting.

Consumers like `ai-agent` reuse the `FIRECRAWL/API_KEY` secret directly (via `apiKeyReference = "FIRECRAWL/API_KEY"`) and connect to `http://127.0.0.1:3002` locally.
