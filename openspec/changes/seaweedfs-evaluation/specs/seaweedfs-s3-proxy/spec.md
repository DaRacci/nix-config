## ADDED Requirements

### Requirement: Only the SeaweedFS S3 endpoint is exposed through Caddy

The system SHALL expose the SeaweedFS S3-compatible HTTP endpoint through `server.proxy.virtualHosts` while keeping internal control and gRPC ports unproxied.

#### Scenario: S3 endpoint proxied through Caddy
- **WHEN** the SeaweedFS evaluation module is active on the IO primary host
- **THEN** it SHALL define a Caddy virtual host that proxies to the configured SeaweedFS S3 HTTP port

#### Scenario: Internal ports remain private
- **WHEN** the SeaweedFS evaluation module is active
- **THEN** it SHALL NOT expose SeaweedFS gRPC or filer-internal ports through Caddy

### Requirement: TLS terminates at Caddy for the evaluation endpoint

The system SHALL terminate TLS at Caddy and forward HTTP traffic to the local SeaweedFS S3 endpoint.

#### Scenario: Proxy forwards request headers suitable for S3 traffic
- **WHEN** Caddy proxies requests to the SeaweedFS S3 endpoint
- **THEN** the proxy configuration SHALL preserve the forwarded headers needed for S3-compatible request handling
