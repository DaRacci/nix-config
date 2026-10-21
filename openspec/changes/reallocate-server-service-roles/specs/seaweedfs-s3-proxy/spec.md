# seaweedfs-s3-proxy Specification

## Purpose

Define how the SeaweedFS evaluation deployment is exposed through the repository's Caddy proxy layer, with proxy routing resolving through the storage primary host instead of assuming localhost on the IO primary.

## MODIFIED Requirements

### Requirement: SeaweedFS evaluation endpoints are exposed through Caddy

The system SHALL expose the SeaweedFS evaluation endpoints through `server.proxy.virtualHosts`, including the S3-compatible HTTP endpoint and the additional HTTP or gRPC endpoints required for the evaluation deployment. Proxy routing to SeaweedFS endpoints SHALL resolve through the storage primary host.

#### Scenario: S3 endpoint proxied through Caddy to storage primary

- **WHEN** the SeaweedFS evaluation module is active
- **THEN** it SHALL define a Caddy virtual host that proxies to the SeaweedFS S3 HTTP port on `config.server.storagePrimaryHost`
- **AND** the back-end target SHALL NOT assume localhost on the IO primary host

#### Scenario: Evaluation component endpoints proxied to storage primary

- **WHEN** the SeaweedFS evaluation module is active
- **THEN** it SHALL define the additional Caddy virtual hosts needed to reach the SeaweedFS evaluation components through the proxy layer
- **AND** all back-end targets SHALL resolve to `config.server.storagePrimaryHost`
