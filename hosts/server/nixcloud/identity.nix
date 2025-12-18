{
  config,
  pkgs,
  ...
}:
{
  sops.secrets =
    let
      kanidmPermissions = {
        owner = "kanidm";
        group = "kanidm";
      };
    in
    {
      "CLOUDFLARE/EMAIL" = { };
      "CLOUDFLARE/ZONE_API_TOKEN" = { };
      "CLOUDFLARE/DNS_API_TOKEN" = { };

      "KANIDM/ADMIN_PASSWORD" = { };
      "KANIDM/IDM_ADMIN_PASSWORD" = { };

      "KANIDM/OAUTH2/NEXTCLOUD_SECRET" = kanidmPermissions;
      "KANIDM/OAUTH2/HASSIO_SECRET" = kanidmPermissions;
      "KANIDM/PROVISIONING_JSON" = kanidmPermissions // {
        sopsFile = ./provisioning.json;
        restartUnits = [ "kanidm.service" ];
        format = "json";
        key = "";
      };
    };

  services.kanidm = {
    enableServer = true;
    package = pkgs.kanidmWithSecretProvisioning_1_8;

    serverSettings =
      let
        certDirectory = config.security.acme.certs."auth.racci.dev".directory;
      in
      rec {
        version = "2";
        domain = "auth.racci.dev";
        origin = "https://${domain}";

        bindaddress = "[::]:8443";

        tls_key = "${certDirectory}/key.pem";
        tls_chain = "${certDirectory}/fullchain.pem";

        http_client_address_info.x-forward-for = [
          "100.97.163.21"
          # "192.168.1.1/24"
          # "192.168.2.1/24"
          # "100.0.0.1/8"
        ];

        online_backup = {
          versions = 7;
          path = "/var/lib/kanidm/backup";
          schedule = "0 3 * * *"; # daily at 3am
        };
      };

    provision = {
      enable = true;
      adminPasswordFile = "/run/credentials/kanidm.service/ADMIN_PASSWORD";
      idmAdminPasswordFile = "/run/credentials/kanidm.service/IDM_ADMIN_PASSWORD";

      # Used for providing information about users that I'd rather not be public.
      extraJsonFile = config.sops.secrets."KANIDM/PROVISIONING_JSON".path;
      groups = {
        sysadmin.members = [ "james" ];

        family.members = [
          "james"
          "savannah"
          "barbara"
        ];

        cloud.members = [
          "family"
          "simon"
        ];
      };

      # Generate OAuth2 Basic Secrets using `cat /dev/urandom | tr --complement --delete 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkpqrstuvwxyz0123456789' | head --bytes 48`
      systems.oauth2 = {
        nextcloud = {
          displayName = "Nextcloud";
          originUrl = "https://nc.racci.dev/apps/user_oidc/code";
          originLanding = "https://nc.racci.dev";
          basicSecretFile = config.sops.secrets."KANIDM/OAUTH2/NEXTCLOUD_SECRET".path;

          scopeMaps.cloud = [
            "openid"
            "profile"
            "email"
            "groups"
          ];
        };

        hassio = {
          public = true;
          displayName = "Home Assistant";
          originUrl = "https://hassio.racci.dev/auth/oidc/callback";
          originLanding = "https://hassio.racci.dev/auth/oidc/welcome";
          basicSecretFile = config.sops.secrets."KANIDM/OAUTH2/HASSIO_SECRET".path;

          scopeMaps.family = [
            "openid"
            "profile"
            "email"
            "groups"
          ];
        };
      };
    };
  };

  server = {
    dashboard.items.auth = {
      title = "Kanidm Identity";
      icon = "sh-kanidm";
    };

    proxy.virtualHosts.auth = {
      public = true;
      extraConfig =
        let
          cfg = config.services.kanidm.serverSettings;
        in
        ''
          reverse_proxy {
            to https://${cfg.bindaddress}
            transport http {
              tls_insecure_skip_verify
            }
          }
        '';
    };
  };

  systemd.services.kanidm = {
    after = [ "acme-auth.racci.dev.service" ];
    serviceConfig.LoadCredential =
      let
        inherit (config.sops) secrets;
      in
      [
        "ADMIN_PASSWORD:${secrets."KANIDM/ADMIN_PASSWORD".path}"
        "IDM_ADMIN_PASSWORD:${secrets."KANIDM/IDM_ADMIN_PASSWORD".path}"
      ];
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

    certs."${config.services.kanidm.serverSettings.domain}" = {
      reloadServices = [ "kanidm.service" ];
      group = "kanidm";
    };
  };

  networking.firewall.allowedTCPPorts = [ 8443 ];
}
