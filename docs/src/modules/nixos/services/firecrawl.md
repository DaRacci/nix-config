# Firecrawl

Generic Firecrawl service wrapper with hardened systemd sandboxing.

- **Entry point**: `modules/nixos/services/firecrawl.nix`
- **Package**: `pkgs.firecrawl`

## Special Options

- `services.firecrawl.enable`: Enable Firecrawl.
- `services.firecrawl.package`: Override package providing Firecrawl binary.
- `services.firecrawl.host`: Bind address.
- `services.firecrawl.port`: Listen port.
- `services.firecrawl.openFirewall`: Open firewall for listen port.
- `services.firecrawl.apiKeyFile`: Compatibility option — generally not needed. The Firecrawl server does not enforce auth from this value. It is loaded via `LoadCredential` for downstream consumers that share the same process environment, but the preferred pattern is for consumers (e.g., ai-agent) to reference the secret directly.
- `services.firecrawl.bullAuthKeyFile`: Optional secret file for queue admin UI auth.
- `services.firecrawl.environment`: Extra environment vars rendered via `sops.templates`.
- `services.firecrawl.extraArgs`: Extra args for service command.
- `services.firecrawl.numWorkersPerQueue`: Worker count per queue (default: 8).
- `services.firecrawl.useDbAuthentication`: Enable DB authentication.
- `services.firecrawl.redisUrl`: Override Redis URL. When null, derived from repo DB module or `redis://127.0.0.1:6379`.
- `services.firecrawl.redisRateLimitUrl`: Override Redis rate-limit URL. When null, derived from repo DB module or `redis://127.0.0.1:6379`.
- `services.firecrawl.databaseUrl`: Override Postgres `DATABASE_URL`. When null, built from repo DB module.

### OpenRouter Options (`services.firecrawl.openrouter.*`)

- `services.firecrawl.openrouter.enable`: Enable OpenRouter integration. Loads `OPENROUTER_API_KEY` via `LoadCredential`.
- `services.firecrawl.openrouter.apiKeyFile`: Path to file containing the OpenRouter API key. Required when `enable = true`.
- `services.firecrawl.openrouter.modelName`: Optional `MODEL_NAME` override (default: Firecrawl upstream default).
- `services.firecrawl.openrouter.modelEmbeddingName`: Optional `MODEL_EMBEDDING_NAME` override (default: Firecrawl upstream default).

### Playwright Options (`services.firecrawl.playwright.*`)

- `services.firecrawl.playwright.browsersPath`: Path to Playwright browsers. Defaults to `pkgs.playwright-driver.browsers` (Nix-managed). Set to `null` to let Playwright manage its own browsers. Exported as `PLAYWRIGHT_BROWSERS_PATH` with `PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1`.

## Auth Model

The Firecrawl server **does not enforce request auth** from any env var. The `FIRECRAWL_API_KEY` secret belongs to **client consumers** (Hermes, ai-agent) that need it to authenticate their Firecrawl API calls.

For public exposure, use **Kanidm OAuth2 at the reverse proxy layer**. The proxy module supports:

- `server.proxy.virtualHosts.<name>.public = true` — exposes via Cloudflare Tunnel
- `server.proxy.virtualHosts.<name>.kanidm.allowGroups` — restricts access to Kanidm groups
- The OAuth2 client secret is stored in `secrets.yaml` as `KANIDM/OAUTH2/FIRECRAWL_SECRET`

There is **no unsecured public endpoint**. All external requests go through Kanidm authentication before reaching the Firecrawl backend.

## OpenRouter Configuration

Firecrawl uses `OPENROUTER_API_KEY` for LLM-powered extraction features. The key is loaded via `LoadCredential` through the module's `openrouter` options:

```nix
services.firecrawl.openrouter = {
  enable = true;
  apiKeyFile = config.sops.secrets."AI_AGENT/OPENROUTER_API_KEY".path;
  # optional model overrides:
  # modelName = "openai/gpt-4o";
  # modelEmbeddingName = "openai/text-embedding-3-small";
};
```

This **reuses the existing `AI_AGENT/OPENROUTER_API_KEY` secret** declared in `hosts/server/nixai/secrets.yaml`. No duplicate secret needed.

## Playwright Browsers

Firecrawl requires Playwright browsers for web scraping. The module defaults `services.firecrawl.playwright.browsersPath` to `pkgs.playwright-driver.browsers`, which exports `PLAYWRIGHT_BROWSERS_PATH` and sets `PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1`. No additional configuration needed for standard NixOS setups.

Override only if you need custom browser paths:

```nix
services.firecrawl.playwright.browsersPath = "/custom/browser/path";
```

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

## Operational Notes

Service runs as `DynamicUser` with strict sandboxing, state in `/var/lib/firecrawl`, and no public port unless `openFirewall` is set.

## Host Wiring (`nixai`)

`nixai` enables Firecrawl with `REDIS/PASSWORD` and `FIRECRAWL/BULL_AUTH_KEY` secrets, keeps it bound to `127.0.0.1`, and exposes it publicly via Kanidm-authenticated reverse proxy.

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

### OpenRouter Wiring

```nix
services.firecrawl.openrouter = {
  enable = true;
  apiKeyFile = config.sops.secrets."AI_AGENT/OPENROUTER_API_KEY".path;
};
```

The key is loaded via `LoadCredential` and exported as `OPENROUTER_API_KEY`. Reuses the existing `AI_AGENT/OPENROUTER_API_KEY` secret — no duplicate declaration needed.

### Local Consumer Access

The `FIRECRAWL/API_KEY` secret is declared but consumed by `ai-agent` (not the Firecrawl server process). Consumers connect to `http://127.0.0.1:3002` directly on the loopback interface.

PostgreSQL (`firecrawl` database + role) and Redis (DB IDs 1 and 2 for `firecrawl` / `firecrawl-rate-limit`) are declared via `server.database.postgres.firecrawl` and `server.database.redis`. The service is registered in `database.dependentServices` so the IO Guardian waits for databases before starting.

Consumers like `ai-agent` reuse the `FIRECRAWL/API_KEY` secret directly (via `apiKeyReference = "FIRECRAWL/API_KEY"`) and connect to `http://127.0.0.1:3002` locally.
