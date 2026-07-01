# Proxy Routing Scenario
# Verifies HTTPS reverse-proxy between nixio caddy and nixcloud backend.
# Self-signed cert generated at build-time, injected into VM via environment.etc.
# curl -k used to skip cert validation (self-signed).
{
  nodes = {
    nixio =
      { pkgs, ... }:
      let
        testCertKey =
          pkgs.runCommand "test.local-key.pem"
            {
              nativeBuildInputs = [ pkgs.openssl ];
            }
            ''
              openssl genrsa -out "$out" 2048
            '';
        testCert =
          pkgs.runCommand "test.local-cert.pem"
            {
              nativeBuildInputs = [ pkgs.openssl ];
            }
            ''
              openssl req -x509 -new -key ${testCertKey} -out "$out" \
                -days 365 -nodes -subj "/CN=test.local"
            '';
      in
      {
        environment.systemPackages = [ pkgs.openssl ];
        environment.etc = {
          "ssl/test.local-key.pem" = {
            source = testCertKey;
            mode = "0440";
            group = "caddy";
          };
          "ssl/test.local-cert.pem" = {
            source = testCert;
            mode = "0444";
          };
        };

        services.caddy = {
          enable = true;
          virtualHosts."https://test.local" = {
            extraConfig = ''
              tls /etc/ssl/test.local-cert.pem /etc/ssl/test.local-key.pem
              reverse_proxy http://nixcloud:8080
            '';
          };
        };

        networking.firewall.allowedTCPPorts = [ 443 ];
      };

    nixcloud = { pkgs, ... }: {
      networking.firewall.allowedTCPPorts = [ 8080 ];
      systemd.services.test-backend = {
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p /tmp/webroot";
          ExecStart = "${pkgs.python3}/bin/python3 -u -m http.server 8080 --directory /tmp/webroot --bind ::";
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

    with subtest("caddy starts and proxies over TLS"):
      nixio.wait_for_unit("caddy.service")
      nixio.wait_for_open_port(443)
      out = nixio.succeed("curl -s -k --resolve test.local:443:127.0.0.1 https://test.local/index.html")
      assert "hello" in out, f"TLS proxy failed, got: {out}"

    with subtest("TLS certificate is valid"):
      out = nixio.succeed("openssl x509 -noout -subject -in /etc/ssl/test.local-cert.pem")
      assert "CN=test.local" in out, f"unexpected subject: {out}"
  '';
}
