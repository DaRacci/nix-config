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
    mapAttrs
    mergeAttrsList
    concatStringsSep
    ;
  inherit (config.server) ioPrimaryHost;

  cfg = config.services.seaweedfs;
  isIOPrimary = ioPrimaryHost == config.networking.hostName;
  sopsPh = config.sops.placeholder;

  baseDir = "/var/lib/seaweedfs";
  master = [ "seaweedfs.racci.dev:443" ];

  sopsAccess = {
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

  mkVHostWithGrpc = domain: attr: {
    additionalListenPorts = [ 10443 ];
    extraConfig = ''
      tls ${config.sops.secrets."SEAWEEDFS/TLS/${toUpper attr.service}_CRT".path} ${
        config.sops.secrets."SEAWEEDFS/TLS/${toUpper attr.service}_KEY".path
      }

      #FIXME:Only allow connections from localhost for now
      @notLocal not client_ip ::1 127.0.0.1
      abort @notLocal

      @grpc protocol grpc
      handle @grpc {
        reverse_proxy localhost:${toString attr.grpcPort} {
          transport http {
            versions h2c
          }
        }
      }

      reverse_proxy http://localhost:${toString attr.port}
    '';
  };

  mkTmpfilesDirAndSecurity = attr: {
    "${attr.dataDir}".d = {
      mode = "0755";
      user = "seaweedfs";
      group = "seaweedfs";
    };
    "${attr.dataDir}/.seaweed".d = {
      mode = "0700";
      user = "seaweedfs";
      group = "seaweedfs";
    };
    "${attr.dataDir}/.seaweed/security.toml"."L+" = {
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

    ${
      map (service: ''
        [grpc.${service}]
        cert = ${sopsPh."SEAWEEDFS/TLS/${service}_CRT"};
        key = ${sopsPh."SEAWEEDFS/TLS/${service}_KEY"};
      '') grpcTLSServices
      |> concatStringsSep "\n"
    }
  '';

  grpcTLSServices = [
    "MASTER"
    "VOLUME"
    "FILER"
    "CLIENT"
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
      # certstrap request-cert --common-name <SERVICE>
      # certstrap sign --expires "2 years" --CA "SeaweedFS CA" <SERVICE>
      secrets = {
        "SEAWEEDFS/JWT/MASTER" = { };
        "SEAWEEDFS/JWT/MASTER_READ" = { };
        "SEAWEEDFS/JWT/FILER" = { };
        "SEAWEEDFS/JWT/FILER_READ" = { };
        "SEAWEEDFS/TLS/CA" = sopsAccess;
      }
      // (
        map (service: {
          "SEAWEEDFS/TLS/${toUpper service}_CRT" = sopsAccess;
          "SEAWEEDFS/TLS/${toUpper service}_KEY" = sopsAccess;
        }) grpcTLSServices
        |> mergeAttrsList
      );

      templates = {
        "SEAWEEDFS/SECURITY/FILER".content = commonSecretToml + ''
          [jwt.filer_signing]
          key = ${sopsPh."SEAWEEDFS/JWT/FILER"};
          expires_after_seconds = 10

          [jwt.filer_signing.read]
          key = ${sopsPh."SEAWEEDFS/JWT/FILER_READ"};
          expires_after_seconds.read = 10

          [filer.expose_directory_metadata]
          enabled = true
        '';

        "SEAWEEDFS/SECURITY/MASTER".content = commonSecretToml + ''
          [jwt.signing]
          key = ${sopsPh."SEAWEEDFS/JWT/MASTER"};
          expires_after_seconds = 10

          [jwt.signing.read]
          key = ${sopsPh."SEAWEEDFS/JWT/MASTER_READ"};
          expires_after_seconds.read = 10
        '';
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
        };
        "filer.seaweedfs" = cfg.filer // {
          service = "filer";
        };
        "s3.seaweedfs" = cfg.filer.s3 // {
          service = "filer";
        };
        "volume.seaweedfs" = cfg.volume // {
          service = "volume";
        };
        "admin.seaweedfs" = {
          service = "client";
          port = 23646;
          grpcPort = 33646;
        };
      }
      |> mapAttrs mkVHostWithGrpc;

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
              -capabilities=vacuum,ec,replication,balance
          '';
          WorkingDirectory = "/var/lib/seaweedfs/worker";
        };
      };
    };
  };
}
