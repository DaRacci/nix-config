## ADDED Requirements

### Requirement: Prometheus scrape targets are auto-generated from host service configurations

The system SHALL, using cluster helper functions (`collectAllAttrsFunc` or equivalent), generate Prometheus scrape configurations that include every server's declared exporters. The existing `metrics-collection` spec validates that exporter services run and individual scrape targets exist; this requirement validates that the *generated scrape config* on the monitoring host matches the *actual exporters running* across all monitored hosts.

#### Scenario: Generated scrape targets match host-declared exporters across multi-node topology

- **GIVEN** a multi-node VM topology with a monitoring primary host (`nixmon`) and at least two target hosts (`nixio` with Caddy + postgres exporters, `nixcloud` with node exporter only)
- **WHEN** the test queries the Prometheus API at `http://nixmon:9090/api/v1/targets`
- **THEN** the active targets SHALL include `nixio:9100` (node), `nixio:2019` (Caddy), `nixio:9187` (postgres)
- **AND** the active targets SHALL include `nixcloud:9100` (node)
- **AND** SHALL NOT include any exporter that is not enabled on the respective hosts (e.g., `nixcloud:9187` SHALL NOT be present)
- **AND** all targets SHALL report state `up`, not merely that the scrape config exists

#### Scenario: Scrape target list reflects host config changes without manual intervention

- **GIVEN** the initial scrape targets include only configured exporters
- **WHEN** an exporter is added to a target host's NixOS config (e.g., enabling Redis exporter on `nixio`)
- **THEN** after applying the config and restarting the target host, Prometheus SHALL automatically discover and scrape the new exporter target
- **AND** the test SHALL assert this without any manual scrape config modification on the monitoring host

### Requirement: Log shipping from remote Alloy instances to central Loki is functional

The system SHALL, when a target host runs the Alloy log agent and the monitoring primary host runs Loki, deliver log lines from the target host to Loki within a bounded time window. The existing `log-aggregation` spec covers deployment structure; this requirement covers end-to-end log delivery and queryability.

#### Scenario: Log line written on target host is queryable in Loki on monitoring host

- **GIVEN** a multi-node VM with a monitoring host (`nixmon` running Loki) and a target host (`nixcloud` running Alloy configured to ship logs to `nixmon`)
- **WHEN** a deterministic log line (e.g., `echo "TEST-LOG-MARKER-$(date +%s)" | logger`) is written on the target host
- **THEN** within 30 seconds, a LogCLI or HTTP API query to Loki on `nixmon` using a label selector matching the target host SHALL return the log line
- **AND** the test SHALL assert the log line content and host label match, not merely that Loki is running

#### Scenario: Alloy on target host connects to Loki and reports no send errors

- **WHEN** Alloy is configured to ship to `loki.nixmon:3100` (or the internal address)
- **THEN** Alloy's internal metrics or logs SHALL report zero send errors for the Loki component
- **AND** the Loki receiver metrics on the monitoring host SHALL report bytes received from the target host

### Requirement: Alert routing delivers fireable alert to declared receiver

The system SHALL route Prometheus alerts according to the receiver topology declared in `modules/nixos/server/monitoring/alerting.nix`. When an alert fires, it SHALL reach the configured receiver (e.g., a webhook URL or notification channel) within the test's observation window. The test SHALL use a self-contained webhook receiver within the VM topology to avoid external dependencies.

#### Scenario: Fired alert reaches self-contained webhook receiver

- **GIVEN** a three-node VM topology with a monitoring host (`nixmon` running Prometheus + Alertmanager), a target host with a fireable alert condition, and a webhook receiver host (`nixserv`) running a minimal HTTP server
- **AND** Alertmanager is configured with a receiver that POSTs to `http://nixserv:8080/alerts`
- **WHEN** the target host triggers a condition that fires a Prometheus alert (e.g., a test-only alert rule with a short `for:` duration)
- **THEN** the webhook receiver SHALL receive an HTTP POST containing the alert payload within 60 seconds of the alert firing
- **AND** the payload SHALL contain the alert name and the target host label

### Requirement: OTLP metrics ingested via Alloy are queryable in Prometheus

The system SHALL accept OTLP metrics from a client host via Alloy's OTLP receiver, forward them to Prometheus, and make them queryable via the Prometheus API. This validates the telemetry pipeline end-to-end: OTLP ingestion, metric translation, storage, and queryability.

#### Scenario: OTLP metric submitted from client host appears in Prometheus query results

- **GIVEN** a three-node VM topology with a monitoring host (`nixmon` running Alloy OTLP receiver + Prometheus), and an OTLP client host (`nixai`)
- **WHEN** a synthetic counter metric (e.g., `test_otlp_requests_total{test_id="vm-scenario-1"}`) is submitted via OTLP HTTP/gRPC from the client host to the Alloy OTLP endpoint on `nixmon`
- **THEN** within 60 seconds, a Prometheus instant query for `test_otlp_requests_total` SHALL return a non-zero value
- **AND** the returned metric SHALL include the label `test_id="vm-scenario-1"` as submitted
