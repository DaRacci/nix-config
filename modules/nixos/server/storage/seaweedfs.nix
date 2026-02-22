{
  config,
  inputs,
  lib,
  ...
}:
let
  inherit (lib) mkIf;
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
    server.proxy.virtualHosts = {
      seaweedfs = {
        extraConfig = ''
          reverse_proxy http://localhost:${toString cfg.master.port}
        '';
        l4 = {
          listenPort = 10443;
          config = ''
            route {
              proxy localhost:${toString cfg.master.grpcPort}
            }
          '';
        };
      };

      "s3.seaweedfs" = {
        extraConfig = ''
          reverse_proxy http://localhost:${toString cfg.filer.s3.port} {
            transport http {
              read_timeout 15m
              write_timeout 15m
            }
          }
        '';
        l4 = {
          listenPort = 10443;
          config = ''
            route {
              proxy localhost:${toString cfg.filer.s3.grpcPort}
            }
          '';
        };
      };

      "volume.seaweedfs" = {
        extraConfig = ''
          reverse_proxy http://localhost:${toString cfg.volume.port}
        '';
        l4 = {
          listenPort = 10443;
          config = ''
            route {
              proxy localhost:${toString cfg.volume.grpcPort}
            }
          '';
        };
      };

      "admin.seaweedfs" = {
        extraConfig = ''
          reverse_proxy http://localhost:23646
        '';

        l4 = {
          listenPort = 10443;
          config = ''
            route {
              proxy localhost:33646
            }
          '';
        };
      };
    };

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
