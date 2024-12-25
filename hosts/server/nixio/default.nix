{ flake, config, modulesPath, pkgs, lib, ... }:
let
  subnets = [
    {
      dns = "100.100.100.100:53";
      ipv4_cidr = "100.64.0.0/10";
      ipv4_arpa = "64.100.in-addr.arpa";
      ipv6_cidr = "fd7a:115c:a1e0::/48";
      ipv6_arpa = "0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1.0.0.0.0.0.f.7.2.0.0.2.ip6.arpa";
      domain = "degu-beta.ts.net";
    }
    {
      dns = "192.168.1.1:53";
      ipv4_cidr = "192.168.1.0/24";
      ipv4_arpa = "1.168.192.in-addr.arpa";
      ipv6_cidr = null;
      ipv6_arpa = null;
      domain = "home";
    }
    {
      dns = "192.168.2.1:53";
      ipv4_cidr = "192.168.2.0/24";
      ipv4_arpa = "2.168.192.in-addr.arpa";
      ipv6_cidr = null;
      ipv6_arpa = null;
      domain = "localdomain";
    }
  ];

  fromAllServers = pipe: lib.trivial.pipe flake.nixosConfigurations ([
    # Exclude the current host
    (lib.filterAttrs (name: _: name != config.system.name))
    # Extract the config from each host
    builtins.attrValues
    (builtins.map (host: host.config))
    # Filter to only servers
    (builtins.filter (config: config.host.device.role == "server"))
  ] ++ pipe);
in
{
  imports = [
    "${modulesPath}/virtualisation/proxmox-lxc.nix"
  ];

  sops.secrets = {
    MINIO_ROOT_CREDENTIALS = {
      inherit (config.users.users.minio) group;
      owner = config.users.users.minio.name;
      restartUnits = [ "minio.service" ];
    };

    "CLOUDFLARE/EMAIL" = { };
    "CLOUDFLARE/DNS_API_TOKEN" = { };
    "CLOUDFLARE/ZONE_API_TOKEN" = { };

    PGADMIN_PASSWORD = {
      owner = config.users.users.pgadmin.name;
      group = config.users.groups.pgadmin.name;
      restartUnits = [ "pgadmin.service" ];
    };

    "POSTGRES/POSTGRES_PASSWORD" = {
      owner = config.users.users.postgres.name;
      group = config.users.groups.postgres.name;
      restartUnits = [ "postgresql.service" "pgadmin.service" ];
      mode = "0440";
    };
  } // fromAllServers [
    (builtins.map (config: config.sops.secrets))
    lib.mergeAttrsList
    (lib.filterAttrs (name: secret: lib.strings.hasPrefix "POSTGRES/" secret.name && lib.hasSuffix "_PASSWORD" secret.name))
    (builtins.mapAttrs (_: value: (builtins.removeAttrs value [ "sopsFileHash" ]) // {
      sopsFile = config.sops.defaultSopsFile;
      # Update owner and groups because it will always be only postgres on this server.
      owner = config.users.users.postgres.name;
      group = config.users.groups.postgres.name;
      # TODO - do i need to clean up the reload services?
    }))
  ];

  users.users = {
    minio.extraGroups = [ "caddy" ]; # Caddy group has access to certs, and minio needs access to its own certs.
    postgres.extraGroups = [ "minio" ]; # For backups to be placed in the minio data directory.
  };

  services = {
    minio = {
      enable = true;
      package = pkgs.minio;
      rootCredentialsFile = config.sops.secrets.MINIO_ROOT_CREDENTIALS.path;
    };

    #region Database Services
    postgresql = {
      enable = true;
      package = pkgs.postgresql_16;
      enableJIT = true;
      enableTCPIP = true;

      authentication = lib.mkOverride 10 (''
        # TYPE  DATABASE  USER  ADDRESS   AUTH-METHOD   [AUTH-OPTIONS]
        local   all       all             peer
        local   all       all             scram-sha-256
      '' + (lib.pipe subnets [
        (builtins.map (subnet: [
          "host  all  all  ${subnet.ipv4_cidr}  scram-sha-256"
        ] ++ lib.optionals (subnet.ipv6_cidr != null) [
          "host  all  all  ${subnet.ipv6_cidr}  scram-sha-256"
        ]))
        lib.flatten
        (builtins.concatStringsSep "\n")
      ]));

      extensions = ps: fromAllServers [
        (builtins.filter (config: config.services.postgresql.enable))
        (builtins.map (config: config.services.postgresql.extensions ps))
        builtins.concatLists
        lib.unique
      ];

      ensureDatabases = fromAllServers [
        (builtins.filter (config: config.services.postgresql.enable && (builtins.length config.services.postgresql.ensureDatabases) >= 1))
        (builtins.map (config: config.services.postgresql.ensureDatabases))
        builtins.concatLists
        lib.unique
      ];

      ensureUsers = fromAllServers [
        (builtins.filter (config: config.services.postgresql.enable && (builtins.length config.services.postgresql.ensureUsers) >= 1))
        (builtins.map (config: config.services.postgresql.ensureUsers))
        builtins.concatLists
        lib.unique
      ];

      initialScript = fromAllServers [
        (builtins.filter (config: config.services.postgresql.enable && config.services.postgresql.initialScript != null))
        (builtins.map (config: config.services.postgresql.initialScript))
        (builtins.filter (path: path != null))
        (builtins.map (path: builtins.readFile path))
        (builtins.concatStringsSep "\n")
        (pkgs.writeText "init-sql-script")
      ];

      settings = {
        password_encryption = "scram-sha-256";

        shared_preload_libraries = fromAllServers [
          (builtins.filter (config: config.services.postgresql.enable && config.services.postgresql.settings.shared_preload_libraries != null))
          (builtins.map (config: config.services.postgresql.settings.shared_preload_libraries))
          (builtins.map (preload:
            if lib.isString preload then [ preload ]
            else preload
          ))
          builtins.concatLists
          lib.unique
        ];
      };
    };

    postgresqlBackup = {
      enable = true;
      compression = "zstd";
      compressionLevel = 12;
      startAt = "*-*-* 03:00:00";
      location = "/var/lib/minio/data/psql-backup";
      databases = config.services.postgresql.ensureDatabases;
    };

    # TODO - can i predefine 2fa?
    # TODO - can i integrate this with the backup service?
    pgadmin = {
      enable = true;
      initialEmail = "admin@racci.dev";
      initialPasswordFile = config.sops.secrets."PGADMIN_PASSWORD".path;
    };
    #endregion

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

        dns = rec {
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
          upstream_dns = (lib.pipe subnets [
            (builtins.map (subnet: [
              "[/${subnet.domain}/]${subnet.dns}"
              "[/${subnet.ipv4_arpa}/]${subnet.dns}"
            ] ++ lib.optionals (subnet.ipv6_arpa != null) [
              "[/${subnet.ipv6_arpa}/]${subnet.dns}"
            ]))
            lib.flatten
          ]) ++ [
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
            "127.0.0.0/8"
            "::1/128"
          ];

          private_networks = lib.trivial.pipe subnets [
            (builtins.map (subnet: [ subnet.ipv4_cidr subnet.ipv6_cidr ]))
            lib.flatten
            (builtins.filter (subnet: subnet != null))
          ];
          allowed_clients = private_networks ++ [
            "127.0.0.0/8"
            "::1/128"
          ];

          use_private_ptr_resolvers = true;
          local_ptr_upstreams = builtins.map (subnet: subnet.dns) subnets;

          enable_dnssec = true;
          edns_client_subnet = {
            enabled = true;
          };
          #endregion
        };

        user_rules = lib.trivial.pipe subnets [
          (builtins.map (subnet: [
            "*.racci.dev^$client=${subnet.ipv4_cidr},dnsrewrite=${config.system.name}.${subnet.domain}"
          ] ++ lib.optionals (subnet.ipv6_cidr != null) [
            "*.racci.dev^$client=${subnet.ipv6_cidr},dnsrewrite=${config.system.name}.${subnet.domain}"
          ]))
          lib.flatten
        ] ++ [
          "@@||nextcloud.racci.dev^$dnsrewrite" # Nextcloud isn't hosted internally yet.
          "@@||s.youtube.com^$important" # Fix YouTube history for IOS App
        ];

        tls = {
          enabled = true;
          server_name = "adguard.racci.dev";

          port_https = 0;
          port_dns_over_tls = 853;
          port_dns_over_quic = 853;

          strict_sni_check = false;
          allow_unencrypted_doh = true;
          certificate_path = "${config.security.acme.certs."adguard.racci.dev".directory}/cert.pem";
          private_key_path = "${config.security.acme.certs."adguard.racci.dev".directory}/key.pem";
        };

        statistics = {
          enabled = true;
          interval = "168h"; # 1 week
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
            (mkFilter "Dandelion Sprout's Anti-Malware List" 12)
            (mkFilter "HaGeZi's Ultimate Blocklist" 49)
            (mkFilter "Dandelion Sprout's Anti pUsh Notifications" 39)
            (mkFilter "HaGeZi's Badware Hoster Blocklist" 55)
            (mkFilter "HaGeZi's Threat Intelligence Feeds" 44)
            (mkFilter "NoCoin Filter List" 8)
          ];
      };
    };

    caddy = {
      enable = true;
      package = pkgs.caddy;
      email = "admin@racci.dev";

      globalConfig = ''
        auto_https "disable_certs"
      '';

      logFormat = ''
        format console
      '';

      # Create a map of virtual hosts using the configurations from other servers.
      # This will iterate the hosts of the flake and pull the virtualHosts configuration from each server.
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
          mkVirtualHost = name: config: lib.nameValuePair "${name}.racci.dev" ({
            hostName = "${name}.racci.dev";
            useACMEHost = "${name}.racci.dev";
          } // config);
        in
        lib.listToAttrs [
          (mkVirtualHost "minio" {
            extraConfig = /*caddyfile*/ ''
              redir /console /console/

              handle_path /console* {
                reverse_proxy http://localhost${config.services.minio.consoleAddress}
              }

              reverse_proxy {
                to http://localhost${config.services.minio.listenAddress}
              }
            '';
          })
          (mkVirtualHost "adguard" {
            # TODO - DNS over HTTPS
            extraConfig = /*caddyfile*/ ''
              redir /dns-query /dns-query/
              handle /dns-query/* {
                reverse_proxy https://${config.services.adguardhome.host}:${toString config.services.adguardhome.port}
              }
              reverse_proxy http://${config.services.adguardhome.host}:${toString config.services.adguardhome.port}
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
          # TODO - move out of dockge
          (mkVirtualHost "finance" {
            extraConfig = /*caddyfile*/ ''
              reverse_proxy http://dockge:3000
            '';
          })
          # TODO - move out of the vm
          (mkVirtualHost "hassio" {
            extraConfig = /*caddyfile*/ ''
              reverse_proxy http://homeassistant:8123
            '';
          })
          # TODO - will this be needed in the future?
          (mkVirtualHost "dockge" {
            extraConfig = /*caddyfile*/ ''
              reverse_proxy http://dockge:5001
            '';
          })
          (mkVirtualHost "pgadmin" {
            extraConfig = /*caddyfile*/ ''
              reverse_proxy http://localhost:${toString config.services.pgadmin.port}
            '';
          })
        ]
      );
    };
  };

  systemd.services = {
    minio.environment = {
      MINIO_DOMAIN = "minio.racci.dev";
      MINIO_BROWSER_REDIRECT_URL = "https://minio.racci.dev/console";
      MINIO_OPTS = "--certs-dir /var/lib/acme/";
    };

    postgresql.postStart = fromAllServers [
      (builtins.filter (config: (builtins.hasAttr "postgresql" config.systemd.services) && config.systemd.services.postgresql.enable && config.systemd.services.postgresql.postStart != [ ]))
      (builtins.map (config: config.systemd.services.postgresql.postStart))
      # We don't want to run the pre-start scripts from each server.
      (builtins.filter (script: !lib.hasSuffix "postgresql-post-start" script))
      (builtins.concatStringsSep "\n")
    ] + "\n" + (lib.mine.mkPostgresRolePass "postgres" config.sops.secrets."POSTGRES/POSTGRES_PASSWORD".path);
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

  #region Site2Site VPN
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };

  services.tailscale = { };
  #endregion

  networking.firewall = {
    allowedTCPPorts = [
      # AdGuardHome
      53
      853

      # Caddy
      80
      443
    ];

    allowedUDPPorts = [
      # AdGuardHome
      53
    ];
  };
}
