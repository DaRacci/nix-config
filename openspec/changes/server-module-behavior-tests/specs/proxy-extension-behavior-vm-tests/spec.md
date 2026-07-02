## ADDED Requirements

### Requirement: Localhost rewrite extension transforms proxied request headers correctly

The system SHALL, when Caddy reverse-proxies a request through a virtual host with the localhost rewrite extension enabled, strip `X-Forwarded-For` and other hop-by-hop headers from the upstream request and replace the `Host` header with the upstream backend address. The existing `proxy-routing` scenario covers basic routing; this requirement covers the rewrite transformation semantics.

#### Scenario: Localhost rewrite removes X-Forwarded-For and replaces Host header

- **GIVEN** a multi-node VM scenario with a proxy host (`nixio` running Caddy) and a backend host (`nixcloud` running an HTTP echo server)
- **AND** a virtual host with localhost rewrite enabled, reverse-proxying to `http://nixcloud:8080`
- **WHEN** a client sends an HTTP request to the virtual host with header `X-Forwarded-For: 1.2.3.4`
- **THEN** the echo server on the backend host SHALL receive the request
- **AND** the request as received by the backend SHALL NOT contain the `X-Forwarded-For` header
- **AND** the `Host` header as received by the backend SHALL be `nixcloud:8080` (or the upstream address), not the original virtual host domain

#### Scenario: Rewrite does not strip X-Forwarded-For when rewrite is not enabled

- **GIVEN** a virtual host without localhost rewrite enabled, reverse-proxying to the same backend
- **WHEN** a client sends a request with `X-Forwarded-For: 1.2.3.4`
- **THEN** the backend SHALL receive the request with `X-Forwarded-For` intact

### Requirement: API-key auth extension rejects unauthenticated requests and passes authenticated ones

The system SHALL, when the API-key auth extension (`modules/nixos/server/proxy/extensions/api-key-auth.nix`) is enabled on a virtual host, reject requests missing the `Req-API-Key` header with HTTP 401 and pass requests with a valid key to the backend. The test SHALL use a deterministic dummy secret set inline (no sops dependency in CI scenario) to validate the auth behavior.

#### Scenario: Request without API key receives 401

- **GIVEN** a virtual host with API-key auth enabled and a known test API key configured
- **WHEN** an HTTP request is sent to the virtual host without the `Req-API-Key` header
- **THEN** the response SHALL be HTTP 401 Unauthorized
- **AND** the response body SHALL NOT contain backend content (i.e., the request never reached the upstream)

#### Scenario: Request with valid API key reaches backend

- **GIVEN** the same virtual host with the same test API key
- **WHEN** an HTTP request includes header `Req-API-Key: <test-key>`
- **THEN** the response SHALL be HTTP 200
- **AND** the response body SHALL contain the expected backend content

#### Scenario: Request with invalid API key receives 401

- **GIVEN** the same virtual host with the same test API key
- **WHEN** an HTTP request includes header `Req-API-Key: wrong-key`
- **THEN** the response SHALL be HTTP 401 Unauthorized

### Requirement: Kanidm auth extension validates tokens via upstream provider

The system SHALL, when the Kanidm auth extension is enabled on a virtual host, reject requests without valid Kanidm session tokens and forward requests with valid tokens to the backend. The test SHALL use a self-contained Kanidm instance within the VM topology (not a production IdP) to validate the token validation handshake.

#### Scenario: Request without Kanidm session token is redirected or rejected

- **GIVEN** a multi-node VM with a proxy host (`nixio` running Caddy + Kanidm auth extension) and a Kanidm IdP host (`nixcloud`)
- **AND** a virtual host with Kanidm auth enabled and `allowGroups` set to a test group
- **WHEN** an HTTP request without a Kanidm session cookie or authorization header is sent
- **THEN** the response SHALL be HTTP 401 or a redirect to the Kanidm login page
- **AND** the request SHALL NOT reach the backend

#### Scenario: Request with valid Kanidm session token reaches backend

- **GIVEN** the same topology
- **WHEN** an HTTP request includes a valid Kanidm session cookie obtained via the Kanidm IdP's authentication API using test credentials
- **THEN** the response SHALL be HTTP 200
- **AND** the response body SHALL contain the expected backend content

### Requirement: L4 TCP forwarding extension reaches backend on correct port

The system SHALL, when the L4 extension (`modules/nixos/server/proxy/extensions/l4.nix`) is configured on a virtual host with a `listenPort`, forward raw TCP connections from the proxy host's `listenPort` to the backend host and port. The test SHALL verify data roundtrip, not just port reachability.

#### Scenario: Raw TCP connection forwarded via L4 extension

- **GIVEN** a multi-node VM with a proxy host and a backend host running a TCP echo service on port 9999
- **AND** a virtual host with `l4.listenPort` set and `l4.config` proxying to the backend's echo port
- **WHEN** a client connects via raw TCP to the proxy host's `listenPort` and sends a deterministic byte sequence
- **THEN** the response SHALL contain the identical byte sequence echoed back (confirming the TCP stream was forwarded to the backend echo service)
- **AND** the connection SHALL remain open for bidirectional streaming
