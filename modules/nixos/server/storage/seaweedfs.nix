{
  config,
  inputs,
  lib,
  ...
}:
let
  inherit (lib)
    mkIf
    toUpper
    toLower
    mapAttrs
    mergeAttrsList
    concatStringsSep
    nameValuePair
    flatten
    attrsToList
    ;
  inherit (config.server) ioPrimaryHost;

  cfg = config.services.seaweedfs;
  isIOPrimary = ioPrimaryHost == config.networking.hostName;
  sopsPh = config.sops.placeholder;

  baseDir = "/var/lib/seaweedfs";
  master = [ "seaweedfs.racci.dev:443" ];

  sopsCertAndKeys = {
    owner = "seaweedfs";
    group = "seaweedfs";
    mode = "0640";
  };

  mkCommonSystemdService =
    extraConfig:
    lib.mkMerge [
      {
        after = [ "network-online.target" ] ++ lib.optional cfg.master.enable "seaweedfs-master.service";
        wants = [ "network-online.target" ];
        requires = lib.optional cfg.master.enable "seaweedfs-master.service";
        wantedBy = [ "multi-user.target" ];

        serviceConfig = {
          User = "seaweedfs";
          Group = "seaweedfs";
          StateDirectory = "seaweedfs";
          RuntimeDirectory = "seaweedfs";
          Restart = "always";
          RestartSec = "45s";
          LimitNOFILE = 65535;
          AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
        };
      }
      extraConfig
    ];

  mkVHost =
    subdomain: attr:
    nameValuePair subdomain {
      # TODO:Secure behind kanidm
      extraConfig = ''
        reverse_proxy http://localhost:${toString attr.port}
      '';
    };

  mkVHostGrpc =
    domain: attr:
    nameValuePair "${domain}:10443" {
      useAcmeCerts = false;
      extraConfig = ''
        tls ${config.sops.secrets."SEAWEEDFS/TLS/${toUpper attr.service}_CRT".path} ${
          config.sops.secrets."SEAWEEDFS/TLS/${toUpper attr.service}_KEY".path
        } {
          protocols tls1.3
          ca_root ${config.sops.secrets."SEAWEEDFS/TLS/CA".path}
          client_auth {
            mode require_and_verify
            trusted_ca_cert_file ${config.sops.secrets."SEAWEEDFS/TLS/CA".path}
          }
        }

        reverse_proxy localhost:${toString attr.grpcPort} {
          transport http {
            tls_trust_pool file ${config.sops.secrets."SEAWEEDFS/TLS/CA".path}
            tls_server_name "${domain}.racci.dev"
            tls_client_auth ${config.sops.secrets."SEAWEEDFS/TLS/${toUpper attr.service}_CRT".path} ${
              config.sops.secrets."SEAWEEDFS/TLS/${toUpper attr.service}_KEY".path
            }
          }
        }
      '';
    };

  mkTmpfilesDirAndSecurity = attr: {
    "${attr.dataDir}".d = {
      mode = "0755";
      user = "seaweedfs";
      group = "seaweedfs";
    };
    "${attr.dataDir}/security.toml"."L+" = {
      mode = "0600";
      user = "seaweedfs";
      group = "seaweedfs";
      argument = config.sops.templates."SEAWEEDFS/SECURITY/${toUpper attr.security}".path;
    };
  };

  commonSecretToml = ''
    [cors.allowed_origins]
    values = "*"

    [access]
    ui = true

    [grpc]
    ca = "${config.sops.secrets."SEAWEEDFS/TLS/CA".path}"

    ${
      map (service: ''
        [grpc.${toLower service}]
        cert = "${config.sops.secrets."SEAWEEDFS/TLS/${service}_CRT".path}"
        key = "${config.sops.secrets."SEAWEEDFS/TLS/${service}_KEY".path}"
      '') grpcTLSServices
      |> concatStringsSep "\n"
    }
  '';

  grpcTLSServices = [
    "MASTER"
    "VOLUME"
    "FILER"
    "CLIENT"
    "ADMIN"
  ];
in
{
  imports = [
    inputs.seaweedfs.outPath
  ];

  config = mkIf isIOPrimary {
    # Access to sops certs.
    users.users.caddy.extraGroups = [ "seaweedfs" ];

    sops = {
      # Generate certs by running
      # certstrap init --common-name "SeaweedFS CA"
      # certstrap request-cert --common-name <SERVICE> --domain <domain> --key-bits 4096
      # certstrap sign --expires "2 years" --CA "SeaweedFS CA" <SERVICE>
      secrets = {
        "SEAWEEDFS/JWT/MASTER" = { };
        "SEAWEEDFS/JWT/MASTER_READ" = { };
        "SEAWEEDFS/JWT/FILER" = { };
        "SEAWEEDFS/JWT/FILER_READ" = { };
        "SEAWEEDFS/TLS/CA" = sopsCertAndKeys;
      }
      // (
        map (service: {
          "SEAWEEDFS/TLS/${toUpper service}_CRT" = sopsCertAndKeys;
          "SEAWEEDFS/TLS/${toUpper service}_KEY" = sopsCertAndKeys;
        }) grpcTLSServices
        |> mergeAttrsList
      );

      templates = {
        "SEAWEEDFS/SECURITY/FILER" = sopsCertAndKeys // {
          content = commonSecretToml + ''
            [jwt.filer_signing]
            key = "${sopsPh."SEAWEEDFS/JWT/FILER"}"
            expires_after_seconds = 10

            [jwt.filer_signing.read]
            key = "${sopsPh."SEAWEEDFS/JWT/FILER_READ"}"
            expires_after_seconds.read = 10

            [filer.expose_directory_metadata]
            enabled = true
          '';
        };

        "SEAWEEDFS/SECURITY/MASTER" = sopsCertAndKeys // {
          content = commonSecretToml + ''
            [jwt.signing]
            key = "${sopsPh."SEAWEEDFS/JWT/MASTER"}"
            expires_after_seconds = 10

            [jwt.signing.read]
            key = "${sopsPh."SEAWEEDFS/JWT/MASTER_READ"}"
            expires_after_seconds.read = 10
          '';
        };
      };
    };

    services.seaweedfs = {
      enable = true;

      master = {
        enable = true;
        ip = "127.0.0.1";
        peers = [ "none" ]; # Faster startup without waiting for peers to be available.
      };

      volume = {
        enable = true;
        ip = "127.0.0.1";
        disk = "nvme";
        maxVolumes = 0; # Use all available disk space.
        idxDir = "/var/lib/seaweedfs/idx";

        inherit master;
      };

      filer = {
        enable = true;
        ip = "127.0.0.1";
        inherit master;

        s3 = {
          enable = true;
          allowDeleteBucketNotEmpty = false;
          domainName = "s3.seaweedfs.racci.dev";
        };
      };
    };

    server.proxy.virtualHosts =
      {
        seaweedfs = cfg.master // {
          service = "master";
          withGrpc = true;
        };
        "filer.seaweedfs" = cfg.filer // {
          service = "filer";
          withGrpc = true;
        };
        "s3.seaweedfs" = cfg.filer.s3 // {
          service = "filer";
          withGrpc = false;
        };
        "volume.seaweedfs" = cfg.volume // {
          service = "volume";
          withGrpc = true;
        };
        "admin.seaweedfs" = {
          service = "admin";
          port = 23646;
          grpcPort = 33646;
          withGrpc = true;
        };
      }
      |> attrsToList
      |> map (a: [
        (mkVHost a.name a.value)
        (mkVHostGrpc a.name a.value)
      ])
      |> flatten
      |> builtins.listToAttrs;

    # nixpkgs PR uses incorrect attribute options and syntax for tmpfiles.
    systemd.tmpfiles.settings = {
      "" = lib.mkForce { };

      seaweedfs-base = lib.mkForce {
        "${baseDir}".d = {
          mode = "0755";
          user = "seaweedfs";
          group = "seaweedfs";
        };
      };

      seaweedfs-worker = {
        "${baseDir}/worker".d = {
          mode = "0755";
          user = "seaweedfs";
          group = "seaweedfs";
        };
      };

      seaweedfs-webdav = lib.mkForce {
        "${cfg.filer.webdav.cacheDir}".d = {
          mode = "0755";
          user = "seaweedfs";
          group = "seaweedfs";
        };
      };
    }
    // (lib.optionalAttrs (cfg.filer.tomlConfig != null) {
      seaweedfs-config = {
        "${baseDir}/.seaweedfs".d = {
          mode = "0755";
          user = "seaweedfs";
          group = "seaweedfs";
        };
        "${baseDir}/.seaweedfs/filer.toml"."f+" = {
          mode = "0644";
          user = "seaweedfs";
          group = "seaweedfs";
          argument = cfg.filer.tomlConfig;
        };
      };
    })
    // (lib.optionalAttrs (cfg.volume.idxDir != null) {
      seaweedfs-idx = {
        "${cfg.volume.idxDir}".d = {
          mode = "0755";
          user = "seaweedfs";
          group = "seaweedfs";
        };
      };
    })
    // (
      {
        seaweedfs-master = cfg.master // {
          security = "master";
        };
        seaweedfs-volume = cfg.volume // {
          security = "master";
        };
        seaweedfs-filer = cfg.filer // {
          security = "filer";
        };
        seaweedfs-admin = {
          security = "master";
          dataDir = "${baseDir}/admin";
        };
      }
      |> mapAttrs (_: v: mkTmpfilesDirAndSecurity v)
    );

    systemd.services = {
      seaweedfs-admin = mkCommonSystemdService {
        description = "SeaweedFS Admin UI Server";
        serviceConfig = {
          ExecStart = ''
            ${cfg.package}/bin/weed admin \
              -port=23646 \
              -dataDir=/var/lib/seaweedfs/admin \
              -masters=${lib.concatStringsSep "," master}
          '';
          WorkingDirectory = "/var/lib/seaweedfs/admin";
        };
      };

      seaweedfs-worker = mkCommonSystemdService {
        description = "SeaweedFS Worker Server";
        serviceConfig = {
          ExecStart = ''
            ${cfg.package}/bin/weed worker \
              -admin=admin.seaweedfs.racci.dev:443 \
              -jobType=vacuum,volume_balance,erasure_coding,admin_script
          '';
          WorkingDirectory = "/var/lib/seaweedfs/worker";
        };
      };
    };
  };
}
