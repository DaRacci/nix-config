## ADDED Requirements

### Requirement: Grafana runs on monitoring primary host with Kanidm OAuth2

The system SHALL deploy Grafana on the monitoring primary host with native OAuth2/OIDC authentication against Kanidm. Grafana SHALL be publicly accessible via a Caddy virtualHost.

#### Scenario: Grafana accessible via public Caddy virtualHost

- **WHEN** the monitoring primary host has the collector enabled
- **THEN** Grafana SHALL be accessible at `grafana.<domain>` via Caddy with `public = true`

#### Scenario: Grafana authenticates via Kanidm OAuth2

- **WHEN** a user navigates to Grafana
- **THEN** Grafana SHALL redirect to Kanidm for authentication using OAuth2/OIDC
- **AND** upon successful authentication, SHALL create a Grafana session with appropriate role

### Requirement: Kanidm OAuth2 client provisioned declaratively

The system SHALL provision a Kanidm OAuth2 client for Grafana using the existing declarative provisioning system in `hosts/server/nixcloud/identity.nix`.

#### Scenario: Grafana OAuth2 client exists in Kanidm

- **WHEN** the identity provisioning is applied on nixcloud
- **THEN** a `grafana` OAuth2 client SHALL exist in Kanidm with appropriate redirect URIs and scopes

### Requirement: Grafana role mapping from Kanidm groups

The system SHALL map Kanidm groups to Grafana roles: `grafana_admins` → Admin, `grafana_editors` → Editor, all authenticated users → Viewer.

#### Scenario: Admin group gets Admin role

- **WHEN** a user in the `grafana_admins` Kanidm group logs into Grafana
- **THEN** the user SHALL have the Grafana Admin role

#### Scenario: Editor group gets Editor role

- **WHEN** a user in the `grafana_editors` Kanidm group logs into Grafana
- **THEN** the user SHALL have the Grafana Editor role

#### Scenario: Default users get Viewer role

- **WHEN** an authenticated user without special group membership logs into Grafana
- **THEN** the user SHALL have the Grafana Viewer role

### Requirement: Grafana datasources provisioned automatically

The system SHALL provision Prometheus and Loki as Grafana datasources automatically. No manual datasource configuration SHALL be required.

#### Scenario: Prometheus datasource available

- **WHEN** Grafana starts on the monitoring primary host
- **THEN** a Prometheus datasource pointing to `http://localhost:9090` SHALL be pre-configured

#### Scenario: Loki datasource available

- **WHEN** Grafana starts on the monitoring primary host
- **THEN** a Loki datasource pointing to `http://localhost:3100` SHALL be pre-configured

### Requirement: Prometheus and Loki LAN-only via Caddy

The system SHALL expose Prometheus and Loki as Caddy virtualHosts with `public = false`, restricting access to LAN only.

#### Scenario: Prometheus accessible from LAN only

- **WHEN** a client on the LAN accesses `prometheus.<domain>`
- **THEN** the request SHALL be proxied to Prometheus on port 9090

#### Scenario: Prometheus blocked from WAN

- **WHEN** a client outside the LAN attempts to access `prometheus.<domain>`
- **THEN** the request SHALL be rejected by iptables rules

#### Scenario: Loki accessible from LAN only

- **WHEN** a client on the LAN accesses `loki.<domain>`
- **THEN** the request SHALL be proxied to Loki on port 3100

#### Scenario: Loki blocked from WAN

- **WHEN** a client outside the LAN attempts to access `loki.<domain>`
- **THEN** the request SHALL be rejected by iptables rules

### Requirement: Default dashboards provisioned

The system SHALL provision a set of default Grafana dashboards covering cluster overview, per-node metrics, application metrics, Proxmox infrastructure, and a log explorer.

#### Scenario: Dashboards available on fresh deployment

- **WHEN** Grafana starts for the first time
- **THEN** pre-provisioned dashboards SHALL be available without manual import

#### Scenario: Dashboard data populates correctly

- **WHEN** a user opens the cluster overview dashboard
- **THEN** metrics from all monitored servers SHALL be visible
