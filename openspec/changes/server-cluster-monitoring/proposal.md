# Server Cluster Monitoring System

## Overview

Implement a comprehensive monitoring and observability stack for the NixOS server cluster using Prometheus (metrics), Loki (logs), and Grafana (visualization). The system will centralize monitoring on `nixmon` while automatically discovering and monitoring all servers in the cluster.

## Goals

- **Centralized Observability**: Single pane of glass for all cluster metrics and logs
- **Auto-Discovery**: Automatically monitor all servers as they're added to the cluster
- **Integrated Authentication**: Leverage existing Kanidm SSO for Grafana access
- **Comprehensive Coverage**: Monitor systems, applications (Caddy, PostgreSQL, Redis), and infrastructure (Proxmox)
- **Proactive Alerting**: Send alerts to Home Assistant and Nextcloud Talk
- **Host-Agnostic Design**: Configure via reusable modules following existing patterns

## Architecture

### Stack Components

- **Prometheus**: Time-series metrics storage and alerting engine
- **Loki**: Log aggregation and storage
- **Grafana**: Unified visualization dashboard
- **Promtail**: Log shipping agent
- **Alertmanager**: Alert routing and notification
- **Exporters**: node_exporter, postgres_exporter, redis_exporter, proxmox_exporter

### Topology

```
nixmon (Collector Host)
├── Prometheus :9090 (LAN-only via Caddy)
├── Loki :3100 (LAN-only via Caddy)
├── Grafana :3000 (Public via Caddy + Kanidm OAuth)
├── Alertmanager :9093
└── Proxmox Exporter :9221

All Server Containers (Auto-discovered)
├── node_exporter :9100 (always)
├── caddy metrics :2019 (if proxy enabled)
├── postgres_exporter :9187 (if postgres enabled)
├── redis_exporter :9121 (if redis enabled)
└── promtail (ships journald logs to Loki)

Proxmox Host (External)
└── API scraped by proxmox_exporter on nixmon
```

### Data Flow

1. **Metrics**: Prometheus scrapes exporters on all containers every 15s
1. **Logs**: Promtail reads journald and pushes to Loki in real-time
1. **Visualization**: Grafana queries Prometheus + Loki
1. **Alerts**: Prometheus → Alertmanager → Home Assistant + Nextcloud Talk

### Authentication

- **Grafana**: Native Kanidm OAuth integration
  - Groups: `grafana_admins` (Admin), `grafana_editors` (Editor), default (Viewer)
  - Provisioned via existing Kanidm system in `nixcloud/identity.nix`
- **Prometheus/Loki**: LAN-only access via Caddy (no public exposure)

## Module Structure

```
modules/flake/
├── allocations.nix                    # [MODIFIED] Add monitoringPrimaryHost option
└── apply/system.nix                   # [MODIFIED] Map to server.monitoringPrimaryHost

modules/nixos/server/
├── default.nix                        # [MODIFIED] Import monitoring module
└── monitoring/                        # [NEW]
    ├── default.nix                    # Main entry, helper functions, imports
    ├── options.nix                    # Define server.monitoring.* options
    ├── collector/                     # Runs on monitoringPrimaryHost only
    │   ├── default.nix                # Conditional imports
    │   ├── prometheus.nix             # Prometheus server + scrape configs
    │   ├── loki.nix                   # Loki server
    │   ├── grafana.nix                # Grafana + Kanidm OAuth + datasources
    │   ├── alerting.nix               # Alertmanager + webhook receivers
    │   └── dashboards.nix             # Provision default dashboards
    ├── exporters/                     # Runs on all monitored hosts
    │   ├── default.nix                # Conditional enablement
    │   ├── node.nix                   # node_exporter (always on)
    │   ├── caddy.nix                  # Enable Caddy metrics endpoint
    │   ├── postgres.nix               # postgres_exporter
    │   └── redis.nix                  # redis_exporter
    ├── logs/
    │   └── promtail.nix               # Promtail agent config
    └── integrations/
        └── proxmox.nix                # Proxmox exporter (on nixmon)

hosts/server/nixcloud/
├── identity.nix                       # [MODIFIED] Add Kanidm grafana OAuth2 client
├── home-assistant/
│   ├── default.nix                    # [MODIFIED] Import monitoring.nix
│   └── monitoring.nix                 # [NEW] Prometheus webhook automation
└── secrets.yaml                       # [MODIFIED] Add HA webhook URL (non-secret)

hosts/server/nixmon/
└── secrets.yaml                       # [MODIFIED] Add monitoring secrets
```

## Configuration Options

### Allocations (Flake-level)

```nix
allocations.server.monitoringPrimaryHost = "nixmon";
```

### Server Module Options

```nix
server.monitoring = {
  enable = true;  # Default: true for all servers
  
  retention = {
    metrics = "90d";  # Prometheus retention
    logs = "90d";     # Loki retention
  };
  
  exporters = {
    node.enable = true;         # Default: true
    caddy.enable = <auto>;      # Auto-enabled if server.proxy enabled
    postgres.enable = <auto>;   # Auto-enabled if postgres configured
    redis.enable = <auto>;      # Auto-enabled if redis configured
  };
  
  logs = {
    enable = true;  # Default: true (runs promtail)
  };
  
  collector = {
    enable = <auto>;  # Auto-enabled on monitoringPrimaryHost
    
    domain = "racci.dev";  # Base domain for subdomains
    
    grafana = {
      kanidm = {
        enable = true;  # Use Kanidm OAuth
        authDomain = "auth.racci.dev";
      };
    };
    
    alerting = {
      homeAssistant.enable = true;
      nextcloudTalk.enable = true;
    };
    
    proxmox = {
      enable = true;
      apiUrl = <from-secret>;
      tokenId = <from-secret>;
      tokenSecret = <from-secret>;
    };
  };
};
```

## Secrets Required

### nixmon/secrets.yaml

```yaml
# Kanidm OAuth (generated by provisioning)
KANIDM:
  OAUTH2:
    GRAFANA_SECRET: "<generated-by-kanidm>"

# Proxmox API Access
MONITORING:
  PROXMOX:
    API_URL: "https://proxmox-host:8006/api2/json"
    TOKEN_ID: "monitoring@pve!prometheus"
    TOKEN_SECRET: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  
  # Home Assistant webhook
  HOME_ASSISTANT:
    WEBHOOK_URL: "https://hassio.racci.dev/api/webhook/prometheus_alerts"
  
  # Nextcloud Talk bot
  NEXTCLOUD_TALK:
    WEBHOOK_URL: "https://nc.racci.dev/ocs/v2.php/apps/spreed/api/v1/bot/{token}/message"
```

## Manual Setup Required

### 1. Proxmox API Token

**Create in Proxmox UI:**

1. Navigate to: Datacenter → Permissions → API Tokens
1. Create user: `monitoring@pve` (if not exists)
1. Create token: `prometheus` (full reference: `monitoring@pve!prometheus`)
1. Enable "Privilege Separation"
1. Assign role: `PVEAuditor` on `/` (Datacenter root)

**Required permissions:**

- PVEAuditor role provides read-only access to:
  - Node statistics (CPU, memory, network)
  - VM/container metrics and status
  - Storage pool usage
  - Cluster health (if applicable)

**Add to secrets:**

```bash
cd hosts/server/nixmon
sops secrets.yaml
# Add MONITORING.PROXMOX.* values
```

### 2. Kanidm Grafana OAuth Secret

**After initial deployment with Kanidm provisioning:**

```bash
# On nixcloud, retrieve the generated secret
sudo kanidm system oauth2 show-basic-secret grafana

# Add to nixmon/secrets.yaml
cd hosts/server/nixmon
sops secrets.yaml
# Add KANIDM.OAUTH2.GRAFANA_SECRET
```

### 3. Home Assistant Webhook

**Automatically configured via NixOS** - no manual steps needed!

The webhook automation will be added to `nixcloud/home-assistant/monitoring.nix`:

- Webhook ID: `prometheus_alerts`
- URL: `https://hassio.racci.dev/api/webhook/prometheus_alerts`

### 4. Nextcloud Talk Bot Token

**You mentioned you already have this** - just add the webhook URL to secrets:

```yaml
MONITORING:
  NEXTCLOUD_TALK:
    WEBHOOK_URL: "https://nc.racci.dev/ocs/v2.php/apps/spreed/api/v1/bot/YOUR_TOKEN/message"
```

## Implementation Phases

### Phase 1: Foundation

- Add `monitoringPrimaryHost` to allocations
- Create monitoring module structure and options
- Implement collector services (Prometheus, Loki, Grafana) on nixmon
- Set up Caddy virtual hosts (Grafana public, Prom/Loki LAN-only)
- Configure Grafana with Kanidm OAuth
- Deploy node_exporter on all servers
- Deploy promtail on all servers

**Validation:**

- Grafana accessible at grafana.racci.dev with Kanidm login
- Prometheus shows all servers in targets (up state)
- Loki receiving logs from all servers
- Can query both metrics and logs in Grafana

### Phase 2: Application Metrics

- Enable Caddy metrics endpoint on proxy servers
- Deploy postgres_exporter on database hosts
- Deploy redis_exporter on cache hosts
- Implement auto-discovery of scrape targets via cluster helpers

**Validation:**

- Caddy metrics visible in Prometheus
- Database metrics visible (queries, connections, etc.)
- Redis metrics visible (memory, keys, operations)

### Phase 3: Proxmox Integration

- Deploy proxmox_exporter on nixmon
- Configure API scraping with secrets

**Validation:**

- Proxmox host metrics visible
- VM/container metrics visible
- Storage metrics visible

### Phase 4: Alerting

- Configure Alertmanager with webhook receivers
- Add Kanidm grafana OAuth2 client provisioning
- Implement Home Assistant automation
- Add Nextcloud Talk webhook
- Define basic alert rules (host down, disk full, high CPU)

**Validation:**

- Test alert fires and reaches Home Assistant
- Test alert fires and posts to Nextcloud Talk
- Alerts visible in Grafana

### Phase 5: Dashboards

- Provision default dashboards for:
  - Cluster overview
  - Node metrics
  - Application metrics (Caddy, PostgreSQL, Redis)
  - Proxmox infrastructure
  - Logs explorer

**Validation:**

- All dashboards load without errors
- Data populates correctly

## Testing Strategy

### Unit Testing (Per Phase)

- Build individual hosts: `nix build .#nixosConfigurations.nixmon.config.system.build.toplevel`
- Check for evaluation errors
- Verify services start: `systemctl status prometheus loki grafana`

### Integration Testing

- Verify scrape targets: http://prometheus.local:9090/targets
- Test log ingestion: Query recent logs in Grafana
- Test OAuth: Login to Grafana with Kanidm account
- Test network restrictions: Ensure Prometheus/Loki not accessible from WAN
- Fire test alert: Simulate condition and verify webhooks

### Cluster-wide Testing

- Use module-graph to identify affected configurations
- Build all affected hosts
- Deploy to test host first, then roll out

## Success Criteria

- [ ] All servers automatically discovered and monitored
- [ ] Metrics retained for 90 days
- [ ] Logs retained for 90 days
- [ ] Grafana accessible via SSO with appropriate role mapping
- [ ] Prometheus and Loki only accessible from LAN
- [ ] Alerts delivered to both Home Assistant and Nextcloud Talk
- [ ] Dashboards show accurate data for all systems
- [ ] Proxmox host and VMs monitored
- [ ] Application metrics (Caddy, PostgreSQL, Redis) available
- [ ] Module follows existing patterns (database, proxy modules)
- [ ] No manual per-host configuration required

## Future Enhancements

(Out of scope for initial implementation)

- Distributed Prometheus (federation)
- Tempo for distributed tracing
- Automatic dashboard generation based on enabled services
- Advanced alert rules (predictive disk space, anomaly detection)
- Metrics from additional applications (MinIO, etc.)
- Log parsing and structured extraction
- Custom Grafana plugins
- Performance tuning for high-cardinality metrics

## References

- NixOS Prometheus: https://search.nixos.org/options?query=services.prometheus
- NixOS Loki: https://search.nixos.org/options?query=services.loki
- NixOS Grafana: https://search.nixos.org/options?query=services.grafana
- Kanidm OAuth2: https://kanidm.com/stable/integrations/oauth2.html
- Proxmox API: https://pve.proxmox.com/wiki/Proxmox_VE_API
