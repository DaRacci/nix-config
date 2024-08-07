{ flake, config, modulesPath, pkgs, lib, ... }: {
  imports = [
    "${modulesPath}/virtualisation/proxmox-lxc.nix"
    "${flake}/hosts/shared/optional/tailscale.nix"
  ];

  sops.secrets = {
    MINIO_ROOT_CREDENTIALS = { };
    "CLOUDFLARE/EMAIL" = { };
    "CLOUDFLARE/DNS_API_TOKEN" = { };
    "CLOUDFLARE/ZONE_API_TOKEN" = { };
  };

  services.resolved.enable = pkgs.lib.mkForce false;

  users.users.minio = {
    extraGroups = [ "caddy" ]; # Caddy group has access to certs, and minio needs access to its own certs.
  };

  services = {
    minio = {
      enable = true;
      package = pkgs.minio;
      rootCredentialsFile = config.sops.secrets.MINIO_ROOT_CREDENTIALS.path;
    };

    adguardhome = {
      enable = true;
      openFirewall = true;
      settings = {
        language = "en";
        theme = "dark";
        users = [
          {
            name = "admin";
            password = "$2a$10$nANKe6mVJ1StB8lZTUHieuhF1sCu/nmzvnXYZyhpsseXQV61ND0lK";
          }
        ];

        dns = {
          bind_hosts = [ "0.0.0.0" ];
          port = 53;

          #region Cache Settings
          cache_size = 4194304;
          cache_ttl_min = 0;
          cache_ttl_max = 0;
          cache_optimistic = true;
          #endregion

          #region DDoS Protection
          ratelimit = 0;
          refuse_any = false;
          #endregion

          #region Upstream Settings
          anonymize_client_ip = false;
          upstream_mode = "parallel";
          upstream_dns = [
            #region local resolvers
            # Allow Unifi to finish .localdomain CNAME's (USA)
            # "[//localdomain/]192.168.1.1"
            # Allow Unifi to finish .localdomain CNAME's (AUS)
            "[/localdomain/]192.168.2.1"
            # Allow Tailscale to finish .degu-beta.ts.net CNAME's
            "[/degu-beta.ts.net/]100.100.100.100"
            #endregion

            #region public resolvers
            "tls://dns10.quad9.net"
            "tls://1dot1dot1dot1.cloudflare-dns.com"
            #endregion
          ];

          bootstrap_dns = [
            "9.9.9.10"
            "149.112.112.10"
            "2620:fe::10"
            "2620:fe::fe:10"
          ];

          fallback_dns = [
            "tls://doh.mullvad.net"
            "tls://dns.google"
          ];

          trusted_proxies = [
            "100.101.160.87/32"
            "192.168.2.207/32"
            "127.0.0.0/8"
            "::1/128"
          ];

          private_networks = [
            "100.0.0.0/8"
            "192.168.1.0/24"
            "192.168.2.0/24"
          ];

          use_private_ptr_resolvers = true;
          local_ptr_upstreams = [
            # Unifi (USA)
            # "192.168.1.1:53"
            # Unifi (AUS)
            "192.168.2.1:53"
            # Tailscale
            "100.100.100.100:53"
          ];
          #endregion
        };

        tls = {
          enabled = true;
          server_name = "adguard.racci.dev";

          port_https = 0;
          port_dns_over_tls = 853;
          port_dns_over_quic = 853;

          strict_sni_check = false;
          allow_unencrypted_doh = true;
          certificate_path = "/data/certificates/adguard.racci.dev/adguard.racci.dev.crt";
          private_key_path = "/data/certificates/adguard.racci.dev/adguard.racci.dev.key";
        };

        filters =
          let
            mkFilter = name: fileId: {
              enabled = true;
              url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_${builtins.toString fileId}.txt";
              inherit name;
              id = fileId;
            };
          in
          [
            (mkFilter "AdGuard DNS filter" 1)
            (mkFilter "AdGuard Default Blocklist" 2)
            (mkFilter "AdGuard DNS Popup Hosts filter" 59)
            (mkFilter "Perflyst and Dandelion Sprout's Smart-TV Blocklist" 7)
            (mkFilter "WindowsSpyBlocker - Hosts spy rules" 23)
            (mkFilter "uBlock filters - Badware risks" 50)
            (mkFilter "1Hosts (Lite)" 24)
            (mkFilter "AWAvenue Ads Rule" 53)
            (mkFilter "Dan Pollock's List" 4)

          ];
      };
    };

    caddy = {
      enable = true;

      # Create a map of virtual hosts using the configurations from other servers.
      # This will need to iterate the hosts of the flake and pull the virtualHosts configuration from each server.
      virtualHosts = lib.trivial.pipe flake.nixosConfigurations [
        # Exclude the current host
        (lib.filterAttrs (name: _: name != config.system.name))
        # Extract the config from each host
        builtins.attrValues
        (builtins.map (host: host.config))
        # Filter to only servers
        (builtins.filter (config: config.host.device.role == "server"))
        # Filter to only servers with at least one caddy virtualHost
        (builtins.filter (config: config.services.caddy ? virtualHosts && config.services.caddy.virtualHosts != { }))
        # Update references in extraConfig to 127.0.0.1 or localhost to the hosts name,
        # Append the domain to the name, and enable the use of ACME provided certs.
        (builtins.map (config: lib.mapAttrs'
          (name: value: lib.nameValuePair "${name}.racci.dev"
            rec {
              hostName = "${name}.racci.dev";
              useACMEHost = hostName;
              extraConfig = builtins.replaceStrings [ "0.0.0.0" "127.0.0.1" "localhost" ] [ config.system.name config.system.name config.system.name ] value.extraConfig;
            } // value)
          config.services.caddy.virtualHosts
        ))
        # Merge all the virtualHosts into a single map
        lib.mergeAttrsList
      ] // (
        let
          mkVirtualHost = name: config: lib.nameValuePair "${name}.racci.dev"
            {
              hostName = "${name}.racci.dev";
              useACMEHost = "${name}.racci.dev";
            } // config;
        in
        lib.listToAttrs [
          (mkVirtualHost "minio" {
            extraConfig = /*caddyfile*/ ''
              redir /console /console/

              handle_path /console/* {
                reverse_proxy http://localhost${config.services.minio.consoleAddress}
              }

              reverse_proxy {
                to https://localhost${config.services.minio.listenAddress}
                # IDK if this is necessary
                transport http {
                  tls
                  tls_server_name minio.racci.dev
                }
              }
            '';
          })
          (mkVirtualHost "adguard" {
            extraConfig = /*caddyfile*/ ''
              reverse_proxy http://${config.services.adguardhome.host}:${config.services.adguardhome.port}
            '';
          })
          (mkVirtualHost "pve" {
            extraConfig = /*caddyfile*/ ''
              reverse_proxy {
                to https://192.168.2.210:8006
                transport http {
                  tls_insecure_skip_verify
                }
              }
            '';
          })
        ]
      );
    };
  };

  systemd.services.minio.environment = {
    MINIO_DOMAIN = "minio.racci.dev";
    MINIO_SERVER_URL = "https://minio.racci.dev";
    MINIO_BROWSER_REDIRECT_URL = "https://minio.racci.dev/console";
    MINIO_OPTS = "--certs-dir /var/lib/acme/";
  };

  security.acme = {
    acceptTerms = true;
    defaults = {
      email = "admin@racci.dev";
      dnsResolver = "1.1.1.1:53";
      dnsProvider = "cloudflare";
      credentialFiles = {
        CLOUDFLARE_EMAIL_FILE = config.sops.secrets."CLOUDFLARE/EMAIL".path;
        CLOUDFLARE_DNS_API_TOKEN_FILE = config.sops.secrets."CLOUDFLARE/DNS_API_TOKEN".path;
        CLOUDFLARE_ZONE_API_TOKEN_FILE = config.sops.secrets."CLOUDFLARE/ZONE_API_TOKEN".path;
      };
    };

    certs = lib.trivial.pipe config.services.caddy.virtualHosts [
      builtins.attrNames
      (builtins.filter (name: lib.strings.hasSuffix ".racci.dev" name))
      (map (name: lib.nameValuePair name { }))
      builtins.listToAttrs
    ];
  };

  networking.firewall = {
    allowedTCPPorts = [ 53 80 443 9000 9001 ];
  };
}
