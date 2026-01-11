{ config, lib, ... }:
let
  inherit (lib) filterEmpty flatten;

  immichOwned = {
    owner = config.users.users.immich.name;
    inherit (config.users.users.immich) group;
  };
in
{
  users = {
    users.immich.uid = 998;
    groups.immich.gid = 998;
  };

  sops.secrets = {
    "IMMICH/ENV" = immichOwned;
  };

  server = {
    database.postgres.immich = {
      password = immichOwned;
    };

    dashboard.items.photos = {
      title = "Immich";
      icon = "sh-immich";
    };

    proxy.virtualHosts.photos.extraConfig =
      let
        cfg = config.services.immich;
      in
      ''
        reverse_proxy http://${cfg.host}:${toString cfg.port}
      '';

    storage.bucketMounts = {
      immich = {
        mountLocation = "/var/lib/immich";
        inherit (config.users.users.immich) uid;
        inherit (config.users.groups.immich) gid;
      };
    };
  };

  services = {
    immich = {
      enable = true;
      host = "0.0.0.0";

      secretsFile = config.sops.secrets."IMMICH/ENV".path;
      environment = {
        IMMICH_TRUSTED_PROXIES =
          config.server.network.subnets
          |> map (subnet: [
            subnet.ipv4.cidr
            subnet.ipv6.cidr
          ])
          |> flatten
          |> filterEmpty
          |> lib.concatStringsSep ",";
      };

      machine-learning.enable = true;

      database =
        let
          db = config.server.database.postgres.immich;
        in
        {
          inherit (db)
            host
            port
            user
            ;

          enableVectors = false; # Will be removed in future versions
          enableVectorChord = true;
        };

      redis = {
        enable = true;
      };

      settings = {
        machineLearning = {
          clip.modelName = "ViT-B-16-SigLIP__webli";
          facialRecognition.modelName = "buffalo_l";
          ocr.modelName = "PP-OCRv5_server";
        };

        oauth = {
          enabled = true;
          buttonText = "Sign in with Kanidm";
          clientId = "immich";
          clientSecret._secret = config.sops.secrets."KANIDM/OAUTH2/IMMICH_SECRET".path;
          issuerUrl = "https://auth.racci.dev/oauth2/openid/immich";
          signingAlgorithm = "ES256";
          scope = "openid email profile";
          tokenEndpointAuthMethod = "client_secret_post";
        };

        server = {
          externalDomain = "https://photos.racci.dev";
          publicUsers = false;
        };

        storageTemplate = {
          enabled = true;
          hashVerificationEnabled = true;
          template = "{{#if album}}{{album-startDate-y}}/{{album}}{{else}}{{y}}/Other/{{MMM}}/{{dd}}/{{/if}}/{{hh}}_{{mm}}_{{ss}}-{{filename}}";
        };

        trash = {
          enabled = true;
          days = 30;
        };
      };
    };
    postgresql.enable = lib.mkForce false;
  };

  systemd.services = {
    immich-server = {
      requires = lib.mkForce [ ];
      after = lib.mkForce [ "network.target" ];
    };

    immich-machine-learning = {
      requires = lib.mkForce [ ];
      after = lib.mkForce [ "network.target" ];
    };
  };

  networking = {
    firewall = {
      allowedTCPPorts = [ config.services.immich.port ];
    };
  };
}
