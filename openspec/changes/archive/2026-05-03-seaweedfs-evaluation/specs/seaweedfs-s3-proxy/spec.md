## ADDED Requirements

### Requirement: SeaweedFS evaluation endpoints are exposed through Caddy

The system SHALL expose the SeaweedFS evaluation endpoints through `server.proxy.virtualHosts`, including the S3-compatible HTTP endpoint and the additional HTTP or gRPC endpoints required for the evaluation deployment.

#### Scenario: S3 endpoint proxied through Caddy

- **WHEN** the SeaweedFS evaluation module is active on the IO primary host
- **THEN** it SHALL define a Caddy virtual host that proxies to the configured SeaweedFS S3 HTTP port

#### Scenario: Evaluation component endpoints proxied through Caddy

- **WHEN** the SeaweedFS evaluation module is active
- **THEN** it SHALL define the additional Caddy virtual hosts needed to reach the SeaweedFS evaluation components through the proxy layer

### Requirement: Caddy terminates client TLS for evaluation endpoints

The system SHALL terminate client-facing TLS at Caddy and forward evaluation traffic to the local SeaweedFS services using the backend transport required by each endpoint.

#### Scenario: Proxy forwards request headers suitable for S3 traffic

- **WHEN** Caddy proxies requests to the SeaweedFS S3 endpoint
- **THEN** the proxy configuration SHALL preserve the forwarded headers needed for S3-compatible request handling

#### Scenario: Proxy forwards component traffic with backend transport settings

- **WHEN** Caddy proxies requests to SeaweedFS component endpoints that require gRPC or mTLS
- **THEN** the proxy configuration SHALL provide the backend transport settings needed for those SeaweedFS components to communicate correctly
