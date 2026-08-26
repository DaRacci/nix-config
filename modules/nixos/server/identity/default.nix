_:
{
  config,
  pkgs,
  lib,
  ...
}:

let
  inherit (lib)
    flatten
    filterEmpty
    mkIf
    mkEnableOption
    mkOption
    types
    literalExpression
    ;
  inherit (types)
    attrsOf
    listOf
    str
    submodule
    ;

  cfg = config.server.identity;
in
{
  options.server.identity = {
    enable = mkEnableOption "Kanidm identity provider";

    domain = mkOption {
      type = str;
      default = "auth.${config.server.proxy.domain}";
      defaultText = literalExpression "auth.\${config.server.proxy.domain}";
      description = "Domain served by the Kanidm identity provider.";
    };

    tlsCertificateDomain = mkOption {
      type = str;
      default = "auth.${config.server.proxy.domain}";
      defaultText = literalExpression "auth.\${config.server.proxy.domain}";
      description = ''
        Domain used for the ACME TLS certificate.
        Defaults to the same value as <option>server.identity.domain</option>.
      '';
    };

    bindAddress = mkOption {
      type = str;
      default = "[::]:8443";
      description = "Address and port Kanidm binds to.";
    };

    backupSchedule = mkOption {
      type = str;
      default = "0 3 * * *";
      description = "Cron schedule for automated Kanidm online backups.";
    };

    backupPath = mkOption {
      type = str;
      default = "/var/lib/kanidm/backup";
      description = "Filesystem path for Kanidm backup storage.";
    };

    backupVersions = mkOption {
      type = types.int;
      default = 7;
      description = "Number of Kanidm backup versions to retain.";
    };

    acmeEmail = mkOption {
      type = str;
      default = "admin@${config.server.proxy.domain}";
      defaultText = literalExpression "admin@\${config.server.proxy.domain}";
      description = "Email address for ACME certificate registration.";
    };

    kanidm = {
      groups = mkOption {
        type = attrsOf (submodule {
          options = {
            members = mkOption {
              type = listOf str;
              default = [ ];
              description = "Members of the Kanidm group.";
            };
          };
        });
        default = { };
        description = "Kanidm groups to provision on startup.";
      };

      oauth2 = mkOption {
        type = attrsOf (
          submodule (_: {
            options = {
              displayName = mkOption {
                type = str;
                description = "Display name for the OAuth2 client.";
              };

              originUrl = mkOption {
                type = types.oneOf [
                  str
                  (listOf str)
                ];
                description = "Origin URL or list of URLs for the OAuth2 client callback.";
              };

              originLanding = mkOption {
                type = str;
                description = "Landing URL after OAuth2 login.";
              };

              basicSecretFile = mkOption {
                type = types.nullOr str;
                default = null;
                description = "Path to the OAuth2 client basic secret file. Required for confidential (non-public) clients; public clients using PKCE should omit this.";
              };

              public = mkOption {
                type = types.bool;
                default = false;
                description = "Whether the OAuth2 client uses PKCE (public client).";
              };

              scopeMaps = mkOption {
                type = attrsOf (listOf str);
                default = { };
                description = "Mapping of group names to allowed scopes.";
              };

              claimMaps = mkOption {
                type = attrsOf (submodule {
                  options = {
                    joinType = mkOption {
                      type = str;
                      default = "array";
                      description = "Join type for claim values (array or csv).";
                    };
                    valuesByGroup = mkOption {
                      type = attrsOf (listOf str);
                      default = { };
                      description = "Mapping of group names to claim values.";
                    };
                  };
                });
                default = { };
                description = "Claim maps for the OAuth2 client.";
              };
            };
          })
        );
        default = { };
        description = ''
          OAuth2 clients to register in Kanidm on startup.
          Each attribute name is the client ID.
        '';
      };

      adminPasswordFile = mkOption {
        type = str;
        description = "Path to the Kanidm admin password file (used via LoadCredential).";
      };

      idmAdminPasswordFile = mkOption {
        type = str;
        description = "Path to the Kanidm IDM admin password file (used via LoadCredential).";
      };

      provisioningJsonFile = mkOption {
        type = str;
        description = "Path to the Kanidm provisioning JSON file containing sensitive user data.";
      };
    };
  };

  config = mkIf cfg.enable {
    services.kanidm = {
      package = pkgs.kanidmWithSecretProvisioning_1_10;

      server = {
        enable = true;
        settings = {
          version = "2";
          domain = cfg.domain;
          origin = "https://${cfg.domain}";

          bindaddress = cfg.bindAddress;

          tls_key = "${config.security.acme.certs.${cfg.tlsCertificateDomain}.directory}/key.pem";
          tls_chain = "${config.security.acme.certs.${cfg.tlsCertificateDomain}.directory}/fullchain.pem";

          http_client_address_info.x-forward-for =
            config.server.network.subnets
            |> map (subnet: [
              subnet.ipv4.cidr
              subnet.ipv6.cidr
            ])
            |> flatten
            |> filterEmpty;

          online_backup = {
            versions = cfg.backupVersions;
            path = cfg.backupPath;
            schedule = cfg.backupSchedule;
          };
        };
      };

      provision = {
        enable = true;
        adminPasswordFile = "/run/credentials/kanidm.service/ADMIN_PASSWORD";
        idmAdminPasswordFile = "/run/credentials/kanidm.service/IDM_ADMIN_PASSWORD";

        extraJsonFile = cfg.kanidm.provisioningJsonFile;
        groups = cfg.kanidm.groups;
        systems.oauth2 = cfg.kanidm.oauth2;
      };
    };

    server = {
      dashboard.items.auth = {
        title = "Kanidm Identity";
        icon = "sh-kanidm";
      };

      proxy.virtualHosts.auth = {
        public = true;
        extraConfig = ''
          reverse_proxy {
            to https://${cfg.bindAddress}
            transport http {
              tls_server_name ${cfg.tlsCertificateDomain}
            }
          }
        '';
      };
    };

    systemd.services.kanidm = {
      after = [ "acme-${cfg.tlsCertificateDomain}.service" ];
      serviceConfig.LoadCredential = [
        "ADMIN_PASSWORD:${cfg.kanidm.adminPasswordFile}"
        "IDM_ADMIN_PASSWORD:${cfg.kanidm.idmAdminPasswordFile}"
      ];
    };

    security.acme = {
      acceptTerms = true;
      defaults = {
        email = cfg.acmeEmail;
        dnsResolver = "1.1.1.1:53";
        dnsProvider = "cloudflare";
        credentialFiles = {
          CLOUDFLARE_EMAIL_FILE = config.sops.secrets."CLOUDFLARE/EMAIL".path;
          CLOUDFLARE_DNS_API_TOKEN_FILE = config.sops.secrets."CLOUDFLARE/DNS_API_TOKEN".path;
          CLOUDFLARE_ZONE_API_TOKEN_FILE = config.sops.secrets."CLOUDFLARE/ZONE_API_TOKEN".path;
        };
      };

      certs.${cfg.tlsCertificateDomain} = {
        reloadServices = [ "kanidm.service" ];
        group = "kanidm";
      };
    };

    networking.firewall.allowedTCPPorts = [
      (lib.toInt (builtins.elemAt (builtins.match ".*:([0-9]+)" cfg.bindAddress) 0))
    ];
  };
}
