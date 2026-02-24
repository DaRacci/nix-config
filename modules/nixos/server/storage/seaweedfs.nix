{
  config,
  inputs,
  lib,
  ...
}:
let
  inherit (lib) mkIf mapAttrs;
  inherit (config.server) ioPrimaryHost;

  cfg = config.services.seaweedfs;
  isIOPrimary = ioPrimaryHost == config.networking.hostName;

  baseDir = "/var/lib/seaweedfs";
  master = [ "seaweedfs.racci.dev:443" ];

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

  mkVHostWithGrpc = domain: optionAttr: {
    additionalListenPorts = [ 10443 ];
    extraConfig = ''
      #FIXME:Only allow connections from localhost for now
      @notLocal not client_ip ::1 127.0.0.1
      abort @denied

      @grpc protocol grpc

      reverse_proxy @grpc localhost:${toString optionAttr.grpcPort} {
        transport http {
          versions h2c
        }
      }

      reverse_proxy http://localhost:${toString optionAttr.port}
    '';
  };
in
{
  imports = [
    inputs.seaweedfs.outPath
  ];

  config = mkIf isIOPrimary {
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
        seaweedfs = cfg.master;
        "filer.seaweedfs" = cfg.filer;
        "s3.seaweedfs" = cfg.filer.s3;
        "volume.seaweedfs" = cfg.volume;
        "admin.seaweedfs" = {
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

      seaweedfs-master = lib.mkForce {
        "${cfg.master.dataDir}".d = {
          mode = "0755";
          user = "seaweedfs";
          group = "seaweedfs";
        };
      };

      seaweedfs-volume = lib.mkForce {
        "${cfg.volume.dataDir}".d = {
          mode = "0755";
          user = "seaweedfs";
          group = "seaweedfs";
        };
      };

      seaweedfs-admin = {
        "${baseDir}/admin".d = {
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

      seaweedfs-filer = lib.mkForce {
        "${cfg.filer.dataDir}".d = {
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
    });

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
