## ADDED Requirements

### Requirement: Virtual host can enable API key authentication

The system SHALL allow any `server.proxy.virtualHosts.<name>` to opt into API key authentication by setting `requireApiKey.enable = true`. When enabled, the system MUST generate a caddy-security `authorize` block that validates the `Req-API-Key` HTTP header against a sops-managed secret unique to that virtual host.

#### Scenario: Enabling API key auth on a virtual host

- **GIVEN** a virtual host `myservice` with `requireApiKey.enable = true`
- **WHEN** the proxy configuration is built
- **THEN** a sops secret path `PROXY_AUTH/MYSERVICE_API_KEY` is registered
- **AND** a caddy `authorize` block named `myservice_apikey` is generated in the global config
- **AND** the vhost's `extraConfig` includes `route /auth/apikey/*` and `authorize with myservice_apikey`

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

### Requirement: authorized requests pass through

The system SHALL allow requests that include the correct `Req-API-Key` header matching the configured secret.

#### Scenario: Valid API key in header

- **WHEN** a request to the virtual host includes header `Req-API-Key` with the correct secret value
- **THEN** the request is authorized and forwarded to the backend

### Requirement: unauthorized requests are rejected

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

### Requirement: API key auth and other auth methods are mutually exclusive

The system SHALL prevent a virtual host from enabling `requireApiKey` alongside any other proxy auth method (any auth extension that injects its own route and authorize directives into the vhost's extraConfig). Enabling both would produce conflicting routing directives.

#### Scenario: Conflict assertion fires

- **GIVEN** a virtual host has both `requireApiKey.enable = true` and another auth method enabled (e.g., `kanidm != null`)
- **WHEN** the configuration is evaluated
- **THEN** an assertion error is raised stating that the auth methods are mutually exclusive
