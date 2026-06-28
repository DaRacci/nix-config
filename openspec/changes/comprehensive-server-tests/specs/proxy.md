# Proxy Integration Tests

## Scope

Caddy reverse proxy running on nixio. ~25 virtual hosts routing to local and remote backends. Covers config load, HTTP response, metrics, Cloudflared integration, and extension wiring.

## Unit Tests (via `server.tests.units`)

### Caddy (nixio)
```nix
server.tests.units.caddy = {
  testScript = { config, ... }: ''
    ${config.host.name}.wait_for_open_port(80)
    ${config.host.name}.wait_for_open_port(443)

    # Root endpoint
    out = ${config.host.name}.succeed("curl -sf -o /dev/null -w '%{http_code}' http://localhost/")
    assert out.strip() == "200", f"caddy root returned {out.strip()}"

    # Caddy admin API
    out = ${config.host.name}.succeed("curl -sf http://localhost:2019/config/")
    assert "apps" in out, "caddy admin API not responding"
  '';
};
```

### Caddy Metrics (nixio, Phase 2)
```nix
server.tests.units.caddy-metrics = {
  testScript = { config, ... }: ''
    ${config.host.name}.wait_for_open_port(3019)
    out = ${config.host.name}.succeed("curl -sf http://localhost:3019/metrics")
    assert "caddy_" in out, "caddy metrics missing"
  '';
};
```

## Scenario Tests

### `proxy-routing` (Phase 2)
- **Nodes**: nixio (caddy) + nixcloud (nextcloud backend)
- **Assert**: HTTP request to nixio with Host header for nextcloud reaches the nextcloud instance on nixcloud

Implementation:
```nix
{
  nodes = {
    nixio = { ... }; # caddy enabled, routes nc.racci.dev → nixcloud:80
    nixcloud = { ... }; # nextcloud enabled, serves on :80
  };
  testScript = ''
    nixio.start()
    nixcloud.start()
    nixio.wait_for_unit("caddy.service")
    nixcloud.wait_for_unit("phpfpm-nextcloud.service")

    with subtest("proxy routes to backend"):
      out = nixio.succeed(
          "curl -sf -H 'Host: nc.racci.dev' http://nixcloud/"
      )
      assert "Nextcloud" in out, "proxy did not route to nextcloud"
  '';
}
```

## Extension-Specific Tests

### Cloudflared Integration
- Cloudflared tunnel needs real credentials — cannot test tunnel ingress in VM
- **Compromise**: Assert `services.cloudflared` unit exists and config parses. Cloudflared service won't start without real tunnel token, but config eval validates.

### L4 Extensions (voice.nix)
- Wyoming Piper/Whisper use L4 TCP proxy extension
- Unit test: port :10200 and :10300 reachable (covered in voice spec)

### Kanidm Auth Extension
- Kanidm extension adds auth header injection to vhosts
- Unit test: Assert that protected vhost extraConfig includes the kanidm auth snippet
- **Cannot test full OAuth2 flow** in VM (needs browser redirect)

## Untestable

- ACME certificate renewal (needs Cloudflare DNS API)
- Cloudflared tunnel ingress (needs real tunnel credentials)
- Full OAuth2 redirect flow through Kanidm
- TLS termination with real certificates
- External DNS resolution (VM uses QEMU host network)
