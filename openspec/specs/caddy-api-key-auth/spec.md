# caddy-api-key-auth Specification

## Purpose
TBD - created by archiving change caddy-api-key-auth. Update Purpose after archive.
## Requirements
### Requirement: API key auth is a self-registering proxy extension

The system SHALL implement API key authentication as a proxy extension registered at `server.proxy.extensions.api-key-auth`, following the extension authoring pattern established by the kanidm extension. The extension file SHALL live at `modules/nixos/server/proxy/extensions/api-key-auth.nix`.

#### Scenario: Extension self-registers in the registry

- **WHEN** the api-key-auth extension file is evaluated
- **THEN** `server.proxy.extensions.api-key-auth` SHALL be set with `priority = 50`, `consumesExtraConfig = true`, and `config`/`globalConfig` functions

#### Scenario: Extension auto-enables when vhosts use it

- **GIVEN** at least one vhost has `requireApiKey.enable = true`
- **WHEN** the configuration is evaluated
- **THEN** `server.proxy.extensions.api-key-auth.enable` SHALL be `mkDefault true`

#### Scenario: Extension stays disabled when no vhost uses it

- **GIVEN** no vhost has `requireApiKey.enable = true`
- **WHEN** the configuration is evaluated
- **THEN** `server.proxy.extensions.api-key-auth.enable` SHALL be `false`
- **AND** the extension's config/globalConfig functions SHALL never be called

### Requirement: Virtual host can enable API key authentication

The system SHALL allow any `server.proxy.virtualHosts.<name>` to opt into API key authentication by setting `requireApiKey.enable = true`. The `requireApiKey` option SHALL be declared by the api-key-auth extension via `options.server.proxy.virtualHosts.<name>.requireApiKey`, merged natively by the NixOS module system.

#### Scenario: Enabling API key auth on a virtual host

- **GIVEN** a virtual host `myservice` with `requireApiKey.enable = true`
- **WHEN** the proxy configuration is built
- **THEN** the extension's `config` function returns Caddy config including an authorize route, handle, and a named matcher `@myservice_apikey_key` that validates the `Req-API-Key` header
- **AND** the extension's `globalConfig` function returns an `order authorize before reverse_proxy` directive and an `authorize` block named `myservice_apikey_authorizer` referencing `with @myservice_apikey_key`

### Requirement: API key secret is auto-generated via sops

The system SHALL register a sops secret for each virtual host with `requireApiKey.enable = true` using the path `PROXY_AUTH/<VHOST_NAME>_API_KEY`, where `<VHOST_NAME>` is the uppercase vhost name with non-alphanumeric characters replaced by underscores.

#### Scenario: Secret path derived from vhost name

- **GIVEN** a virtual host named `radarr`
- **WHEN** `requireApiKey.enable = true`
- **THEN** the sops secret path is `PROXY_AUTH/RADARR_API_KEY`

#### Scenario: Secret path normalization

- **GIVEN** a virtual host named `my-service` (contains hyphen)
- **WHEN** `requireApiKey.enable = true`
- **THEN** the sops secret path is `PROXY_AUTH/MY_SERVICE_API_KEY`

### Requirement: Named Caddy matcher validates API key header

The extension's per-vhost `config` function SHALL emit a named Caddy matcher `@<name>_apikey_key` that validates the `Req-API-Key` HTTP header against the sops-managed secret loaded via environment variable. The `globalConfig` function's `authorize` block SHALL reference this matcher via `with @<name>_apikey_key`.

#### Scenario: Named matcher and authorize block generated

- **GIVEN** a virtual host `radarr` with `requireApiKey.enable = true`
- **WHEN** the configuration is built
- **THEN** the vhost's extraConfig contains:
  ```
  @radarr_apikey_key {
    header Req-API-Key {env.API_KEY_RADARR}
  }
  ```
- **AND** the global config contains:
  ```
  order authorize before reverse_proxy
  authorize with radarr_apikey_authorizer {
    with @radarr_apikey_key
  }
  ```

#### Scenario: Multiple api-key vhosts each get their own matcher and authorize block

- **GIVEN** virtual hosts `radarr` and `sonarr` both have `requireApiKey.enable = true`
- **WHEN** the configuration is built
- **THEN** two separate named matchers exist: `@radarr_apikey_key` and `@sonarr_apikey_key`
- **AND** two separate `authorize` blocks exist: `radarr_apikey_authorizer` and `sonarr_apikey_authorizer`
- **AND** each authorize block references its own matcher: `with @radarr_apikey_key` and `with @sonarr_apikey_key`

#### Scenario: Authorize block uses named matcher reference syntax

- **GIVEN** a virtual host `radarr` with `requireApiKey.enable = true`
- **WHEN** the configuration is built
- **THEN** the global config `authorize` block SHALL reference the named matcher using `with @radarr_apikey_key` syntax
- **AND** SHALL NOT use inline header matcher syntax (e.g., `with http.request.header.Req-API-Key`)

### Requirement: Secret loaded via systemd LoadCredential

The system SHALL configure `systemd.services.caddy.serviceConfig.LoadCredential` entries for each api-key secret, using the credential name `API_KEY_<VHOST>` pointing to the sops secret path. This SHALL only apply on the IO primary host.

#### Scenario: LoadCredential configured for api-key secret

- **GIVEN** a vhost `radarr` with `requireApiKey.enable = true`
- **WHEN** the configuration is built on the IO primary host
- **THEN** `systemd.services.caddy.serviceConfig.LoadCredential` includes `API_KEY_RADARR:<sops-secret-path>`

### Requirement: Authorized requests pass through

The system SHALL allow requests that include the correct `Req-API-Key` header matching the configured secret.

#### Scenario: Valid API key in header

- **WHEN** a request to the virtual host includes header `Req-API-Key` with the correct secret value
- **THEN** the request is authorized and forwarded to the backend

### Requirement: Unauthorized requests are rejected

The system SHALL reject requests that are missing the `Req-API-Key` header or include an incorrect value.

#### Scenario: Missing API key header

- **WHEN** a request to the virtual host does NOT include the `Req-API-Key` header
- **THEN** the request is rejected with a 401 Unauthorized response

#### Scenario: Incorrect API key header

- **WHEN** a request includes header `Req-API-Key` with a value that does not match the configured secret
- **THEN** the request is rejected with a 401 Unauthorized response

### Requirement: Path bypass support

The system SHALL allow specific path patterns to bypass API key authentication via `requireApiKey.bypassPaths`.

#### Scenario: Bypassed path skips authentication

- **GIVEN** `requireApiKey.bypassPaths = [ "/health" ]`
- **WHEN** a request is made to `/health` without a `Req-API-Key` header
- **THEN** the request is forwarded to the backend without authentication

#### Scenario: Non-bypassed path requires authentication

- **GIVEN** `requireApiKey.bypassPaths = [ "/health" ]`
- **WHEN** a request is made to `/api/data` without a `Req-API-Key` header
- **THEN** the request is rejected with a 401 Unauthorized response

### Requirement: API key auth and kanidm auth are mutually exclusive per vhost

Both the api-key-auth extension and the kanidm extension SHALL set `consumesExtraConfig = true`. The existing assertion in `config.nix` (vhostsWithMultipleConsumers) SHALL prevent both from being enabled on the same vhost. No custom assertion is required.

#### Scenario: Conflict assertion fires when both extensions enabled on same vhost

- **GIVEN** a virtual host has both `requireApiKey.enable = true` and `kanidm != null`
- **AND** both extensions are globally enabled (either via `extensions = null` or both listed)
- **WHEN** the configuration is evaluated
- **THEN** an assertion error is raised stating that the vhost has multiple extensions with `consumesExtraConfig = true`

#### Scenario: User resolves conflict by whitelisting one extension

- **GIVEN** a virtual host has both `requireApiKey.enable = true` and `kanidm != null`
- **AND** the user sets `extensions = [ "api-key-auth" ]`
- **WHEN** the configuration is evaluated
- **THEN** only the api-key-auth extension runs on that vhost
- **AND** no assertion error is raised

