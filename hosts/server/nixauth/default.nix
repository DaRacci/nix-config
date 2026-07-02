{ config, lib, ... }:
let
  inherit (lib)
    nameValuePair
    mapAttrs'
    toUpper
    ;
in
{
  core.sops.hostSecretsFile = ../nixcloud/secrets.yaml;

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
      "KANIDM/PROVISIONING_JSON" = kanidmPermissions // {
        sopsFile = ./provisioning.json;
        restartUnits = [ "kanidm.service" ];
        format = "json";
        key = "";
      };
    }
    // (
      config.server.identity.kanidm.oauth2
      |> lib.filterAttrs (_: client: !client.public)
      |> mapAttrs' (
        clientId: _: nameValuePair "KANIDM/OAUTH2/${toUpper clientId}_SECRET" kanidmPermissions
      )
    );

  server.identity = {
    enable = true;

    kanidm = {
      adminPasswordFile = config.sops.secrets."KANIDM/ADMIN_PASSWORD".path;
      idmAdminPasswordFile = config.sops.secrets."KANIDM/IDM_ADMIN_PASSWORD".path;
      provisioningJsonFile = config.sops.secrets."KANIDM/PROVISIONING_JSON".path;

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

      oauth2 = {
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

        immich = {
          displayName = "Immich";
          originUrl = [
            "https://photos.racci.dev/auth/login"
            "https://photos.racci.dev/user-settings"
            "app.immich:///oauth-callback"
          ];
          originLanding = "https://photos.racci.dev";
          basicSecretFile = config.sops.secrets."KANIDM/OAUTH2/IMMICH_SECRET".path;

          scopeMaps.cloud = [
            "openid"
            "profile"
            "email"
          ];
          claimMaps.immich_role = {
            joinType = "csv";
            valuesByGroup = {
              sysadmin = [ "admin" ];
              cloud = [ "user" ];
            };
          };
        };

        grafana = {
          displayName = "Grafana";
          originUrl = "https://grafana.racci.dev/login/generic_oauth";
          originLanding = "https://grafana.racci.dev";
          public = true;

          scopeMaps.sysadmin = [
            "openid"
            "profile"
            "email"
            "groups"
          ];
          claimMaps.grafana_role = {
            joinType = "array";
            valuesByGroup = {
              sysadmin = [ "admin" ];
            };
          };
        };

        hermes = {
          displayName = "Agent Dashboard";
          originUrl = "https://agent.racci.dev/auth/callback";
          originLanding = "https://agent.racci.dev";
          public = true;

          scopeMaps.cloud = [
            "openid"
            "profile"
            "email"
          ];
        };
      };
    };
  };
}
