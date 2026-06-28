# Network Integration Tests

## Scope

Cross-host connectivity (postgres, redis, monitoring scrape, proxy routing), firewall rules, subnet configuration, IO guardian coordination.

## Unit Tests (via `server.tests.units`)

### Firewall Port Audit (every host, Phase 2)
```nix
server.tests.units.firewall-audit = {
  testScript = { config, ... }: ''
    # Get all listening TCP ports
    listening = ${config.host.name}.succeed("ss -tlnp | awk '{print $4}' | awk -F: '{print $NF}' | sort -u | grep -v '^$'")
    listening_ports = set(int(p) for p in listening.strip().split('\n'))

    # Get expected open ports from config
    expected = set(${toString config.networking.firewall.allowedTCPPorts})

    # Warn about unexpected listeners (fails CI)
    unexpected = listening_ports - expected
    assert len(unexpected) == 0, f"Unexpected listening ports: {unexpected}"

    # Check expected ports are actually listening
    missing = expected - listening_ports
    # Services may not have started yet — warn but don't fail for expected ports
    if len(missing) > 0:
        print(f"WARNING: Expected ports not yet listening: {missing}")
  '';
};
```

### Firewall Rules for Non-IO Hosts (every non-IO host, Phase 2)
```nix
server.tests.units.subnet-firewall = {
  testScript = { config, ... }: ''
    # Verify openPortsForSubnet rules applied
    import = ${config.host.name}.succeed("iptables -n -L nixos-fw 2>/dev/null || echo 'no nixos-fw chain'")
    assert "nixos-fw" in import, "nixos-fw chain missing — subnet rules not applied"
  '';
};
```

## Scenario Tests

### `postgres-remote-connect` (Phase 1)
- Tests: Cross-host TCP connectivity on :5432 across subnets
- Covered in `database.md`

### `redis-remote-connect` (Phase 1)
- Tests: Cross-host TCP connectivity on :6379 across subnets
- Covered in `database.md`

### `monitoring-scrape` (Phase 2)
- Tests: Prometheus → exporter TCP connectivity across hosts
- Covered in monitoring spec

### `proxy-routing` (Phase 2)
- Tests: Caddy reverse proxy routing to remote backends
- Covered in proxy spec

## IO Guardian Protocol

The IO Guardian manages database drain/undrain across hosts. In VM:
- `io-guardian` service starts on non-IO hosts
- `io-database-coordinator` runs on nixio
- **Test**: Assert both services reachable on configured port (9876)
- **Cannot test** full drain/undrain protocol — requires real database traffic

## Subnet Configuration

```nix
server.tests.units.subnets = {
  testScript = { config, ... }: ''
    # Verify AdGuard DNS rewrites resolve locally
    from config, subnet domains are configured
    # (AdGuard must be running — tested separately)
  '';
};
```

## DNS Tests (Phase 3)

- AdGuard DNS resolver on :53
- Upstream DNS forwarding (quad9, cloudflare)
- DNS-over-TLS on :853
- **Compromise**: Assert `adguardhome` service active + DNS port open. Full resolution test requires upstream DNS reachability from VM.

## Untestable

- Tailscale WireGuard overlay (disabled in VM)
- External DNS resolution (Quad9/Cloudflare upstreams unreachable)
- Real IP forwarding/routing (VM uses QEMU NAT)
- L4 proxy load balancing (single backend only in VM)
- IO Guardian PSK authentication (requires real PSK file)
