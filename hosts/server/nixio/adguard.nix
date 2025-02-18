{ subnets, mkVirtualHost, ... }:
{ config, lib, ... }:
{
  systemd.services.adguardhome = {
    requires = [ "acme-finished-adguard.racci.dev.target" ];
    serviceConfig.LoadCredential = let
      certDir = config.security.acme.certs."adguard.racci.dev".directory;
    in [
      "cert.pem:${certDir}/cert.pem"
      "key.pem:${certDir}/key.pem"
    ];
  };

  services = {
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
          upstream_dns =
            (lib.pipe subnets [
              (builtins.map (
                subnet:
                [
                  "[/${subnet.domain}/]${subnet.dns}"
                  "[/${subnet.ipv4_arpa}/]${subnet.dns}"
                ]
                ++ lib.optionals (subnet.ipv6_arpa != null) [ "[/${subnet.ipv6_arpa}/]${subnet.dns}" ]
              ))
              lib.flatten
            ])
            ++ [
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
            (builtins.map (subnet: [
              subnet.ipv4_cidr
              subnet.ipv6_cidr
            ]))
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

        user_rules =
          lib.trivial.pipe subnets [
            (builtins.map (
              subnet:
              [
                "*.racci.dev^$client=${subnet.ipv4_cidr},dnsrewrite=${config.system.name}.${subnet.domain}"
              ]
              ++ lib.optionals (subnet.ipv6_cidr != null) [
                "*.racci.dev^$client=${subnet.ipv6_cidr},dnsrewrite=${config.system.name}.${subnet.domain}"
              ]
            ))
            lib.flatten
          ]
          ++ [
            "@@||nextcloud.racci.dev^$dnsrewrite" # Nextcloud isn't hosted internally yet.
            "@@||cloud.racci.dev^$dnsrewrite" # Digital Ocean DNS
            "@@||s.youtube.com^$important" # Fix YouTube history for IOS App
          ];

        tls = {
          enabled = true;
          server_name = "adguard.racci.dev";

          port_https = 8443;
          port_dns_over_tls = 853;
          port_dns_over_quic = 853;

          strict_sni_check = false;
          allow_unencrypted_doh = true;
          certificate_path = "/run/credentials/adguardhome.service/cert.pem";
          private_key_path = "/run/credentials/adguardhome.service/key.pem";
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

    caddy.virtualHosts = lib.listToAttrs [
      (mkVirtualHost "adguard" {
        # TODO - DNS over HTTPS
        extraConfig = ''
          reverse_proxy http://${config.services.adguardhome.host}:${toString config.services.adguardhome.port}
        '';
      })
    ];
  };

  networking.firewall = let cfg = config.services.adguardhome.settings; in {
    allowedTCPPorts = [
      settings.dns.port
      settings.tls.port_https
      settings.tls.port_dns_over_tls
      settings.tls.port_dns_over_quic
    ];

    allowedUDPPorts = [ settings.dns.port ];
  };
}
