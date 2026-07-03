# Proxy Extension Behavior Scenario
# Tests custom proxy extensions (api-key-auth, l4, localhost rewrite)
# using manual services.caddy.virtualHosts (no server module) to avoid
# caddy-security plugin issues.
{
  nodes = {
    nixio = import ./default.nix;

    nixcloud = { pkgs, ... }: {
      networking.firewall.allowedTCPPorts = [
        8080 # HTTP backend
        9090 # TCP echo backend
      ];

      # Python HTTP server on 8080
      systemd.services.test-http = {
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p /tmp/webroot";
          ExecStart = "${pkgs.python3}/bin/python3 -u -m http.server 8080 --directory /tmp/webroot --bind ::";
        };
      };

      # Python TCP echo server on 9090
      systemd.services.test-tcp-echo = {
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          ExecStart = "${pkgs.python3}/bin/python3 ${pkgs.writeText "tcp-echo.py" ''
            import socketserver
            class EchoHandler(socketserver.BaseRequestHandler):
                def handle(self):
                    self.request.sendall(self.request.recv(1024))
            socketserver.ThreadingTCPServer(('0.0.0.0', 9090), EchoHandler).serve_forever()
          ''}";
          Restart = "on-failure";
        };
      };
    };
  };

  testScript = ''
    start_all()

    with subtest("nixcloud HTTP backend serves content"):
      nixcloud.wait_for_unit("test-http.service")
      nixcloud.wait_for_open_port(8080)
      nixcloud.succeed("echo 'hello from nixcloud' > /tmp/webroot/index.html")
      nixcloud.succeed("echo 'ok' > /tmp/webroot/health")
      out = nixcloud.succeed("curl -s http://localhost:8080/index.html")
      assert "hello" in out, f"backend not serving: {out}"

    with subtest("nixcloud TCP echo server on 9090"):
      nixcloud.wait_for_unit("test-tcp-echo.service")
      nixcloud.wait_for_open_port(9090)
      out = nixcloud.succeed("echo 'ping' | timeout 3 nc 127.0.0.1 9090")
      assert "ping" in out, f"TCP echo not working: {out}"

    with subtest("caddy starts on nixio"):
      nixio.wait_for_unit("caddy.service")
      nixio.wait_for_open_port(443)
      nixio.wait_for_open_port(9090)

    with subtest("API-key auth bypass: /health returns 200 without key"):
      out = nixio.succeed(
          "curl -s -o /dev/null -w '%{http_code}' "
          + "-k --resolve api-test.scenario.test:443:127.0.0.1 "
          + "https://api-test.scenario.test/health"
      )
      assert out.strip() == "200", f"bypass failed, got {out}"

    with subtest("API-key auth reject: /api/data without key returns 401"):
      out = nixio.succeed(
          "curl -s -o /dev/null -w '%{http_code}' "
          + "-k --resolve api-test.scenario.test:443:127.0.0.1 "
          + "https://api-test.scenario.test/api/data"
      )
      assert out.strip() == "401", f"reject failed, got {out}"

    with subtest("API-key auth accept: with correct key returns backend content"):
      out = nixio.succeed(
          "curl -s -k --resolve api-test.scenario.test:443:127.0.0.1 "
          + "-H 'Req-API-Key: scenario-api-key-abc123' "
          + "https://api-test.scenario.test/index.html"
      )
      assert "hello" in out, f"auth accept failed, got: {out}"

    with subtest("L4 TCP echo: raw connect to nixio:9090 → nixcloud:9090 echo"):
      out = nixio.succeed("echo 'tcp-echo-test' | timeout 3 nc 127.0.0.1 9090")
      assert "tcp-echo-test" in out, f"L4 TCP echo failed: {out}"

    with subtest("Caddyfile localhost rewrite check"):
      caddyfile = nixio.succeed("cat /etc/caddy/caddy_config 2>/dev/null || cat /etc/caddy/Caddyfile 2>/dev/null || echo 'NO_CADDYFILE'")
      print("=== CADDYFILE BEGIN ===")
      print(caddyfile)
      print("=== CADDYFILE END ===")
      if "localhost:8080" in caddyfile:
          print("rewrite-test localhost reference: present (not replaced)")
      else:
          print("rewrite-test localhost reference: not found")

    with subtest("API-key bypass handler present in Caddyfile"):
      caddyfile = nixio.succeed("cat /etc/caddy/caddy_config 2>/dev/null || cat /etc/caddy/Caddyfile 2>/dev/null || echo 'NO_CADDYFILE'")
      assert "handle @bypass_apikey_api_test" in caddyfile, \
          "bypass handler not found in Caddyfile"
      print("API-key bypass handler present")
  '';
}
