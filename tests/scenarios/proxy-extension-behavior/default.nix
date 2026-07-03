{
  pkgs,
  ...
}:
let
  testCertKey =
    pkgs.runCommand "scenario.test-key.pem"
      {
        nativeBuildInputs = [ pkgs.openssl ];
      }
      ''
        openssl genrsa -out "$out" 2048
      '';
  testCert =
    pkgs.runCommand "scenario.test-cert.pem"
      {
        nativeBuildInputs = [ pkgs.openssl ];
      }
      ''
        openssl req -x509 -new -key ${testCertKey} -out "$out" \
          -days 365 -nodes -subj "/CN=scenario.test"
      '';

  # Embedded API key for the api-test virtual host.
  # Injected via systemd LoadCredential; referenced in Caddyfile as {env.API_KEY_API_TEST}.
in
{
  services.caddy = {
    enable = true;

    package = pkgs.caddy.withPlugins {
      plugins = [ "github.com/mholt/caddy-l4@v0.1.1" ];
      hash = "sha256-/ebF+f235CR36VKfCITtQWXr9wojpgsszxxnZ8HeCd0=";
    };

    globalConfig = ''
      layer4 {
        :9090 {
          route {
            proxy nixcloud:9090
          }
        }
      }
    '';

    virtualHosts."https://api-test.scenario.test" = {
      serverAliases = [ "api-test.scenario.test" ];
      extraConfig = ''
        tls /etc/ssl/scenario.test-cert.pem /etc/ssl/scenario.test-key.pem

        @bypass_apikey_api_test path /health
        handle @bypass_apikey_api_test {
          reverse_proxy http://nixcloud:8080
        }

        @api_test_apikey header Req-API-Key {env.API_KEY_API_TEST}
        handle @api_test_apikey {
          reverse_proxy http://nixcloud:8080
        }

        handle {
          respond "Unauthorized" 401
        }
      '';
    };

    virtualHosts."https://rewrite-test.scenario.test" = {
      serverAliases = [ "rewrite-test.scenario.test" ];
      extraConfig = ''
        tls /etc/ssl/scenario.test-cert.pem /etc/ssl/scenario.test-key.pem
        reverse_proxy http://localhost:8080
      '';
    };
  };

  environment.etc."ssl/scenario.test-key.pem" = {
    source = testCertKey;
    mode = "0440";
    group = "caddy";
  };
  environment.etc."ssl/scenario.test-cert.pem" = {
    source = testCert;
    mode = "0444";
  };

  users.users.caddy = {
    isSystemUser = true;
    group = "caddy";
  };
  users.groups.caddy = { };

  systemd.services.caddy.serviceConfig.Environment = [
    "API_KEY_API_TEST=scenario-api-key-abc123"
  ];

  environment.systemPackages = with pkgs; [
    openssl
    netcat
  ];

  networking.firewall.allowedTCPPorts = [
    443 # API / rewrite test
    9090 # L4 TCP proxy
  ];
}
