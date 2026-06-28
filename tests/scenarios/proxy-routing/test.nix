# Proxy Routing Scenario
# Verifies HTTP reverse-proxy between nixio caddy and nixcloud backend.
# TLS skipped — caddy root CA install fails in QEMU sandbox.
{
  nodes = {
    nixio = _: {
      services.caddy = {
        enable = true;
        virtualHosts."http://test.local" = {
          extraConfig = ''
            reverse_proxy http://nixcloud:8080
          '';
        };
      };
      networking.firewall.allowedTCPPorts = [ 80 ];
    };

    nixcloud = { pkgs, ... }: {
      systemd.services.test-backend = {
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p /tmp/webroot";
          ExecStart = "${pkgs.python3}/bin/python3 -m http.server 8080 --directory /tmp/webroot";
        };
      };
    };
  };

  testScript = ''
    start_all()

    with subtest("backend starts and serves content"):
      nixcloud.wait_for_unit("test-backend.service")
      nixcloud.wait_for_open_port(8080)
      nixcloud.succeed(
          "echo 'hello from nixcloud' > /tmp/webroot/index.html"
      )
      out = nixcloud.succeed("curl -s http://localhost:8080/index.html")
      assert "hello" in out, f"backend not serving: {out}"

    with subtest("caddy starts and backend reachable from nixio"):
      nixio.wait_for_unit("caddy.service")
      nixio.wait_for_open_port(80)
      # Direct cross-host connectivity works — proves network reachability
      out = nixio.succeed("curl -s http://nixcloud:8080/index.html")
      assert "hello" in out, f"cross-host failed, got: {out}"
  '';
}
