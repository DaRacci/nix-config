{
  config,
  lib,
  self,
  ...
}:
let
  inherit (lib)
    mkIf
    mkMerge
    optional
    ;

  swLib = import ./lib.nix {
    inherit config lib;
  };

  cfg = config.services.seaweedfs;

  defaultMaster = [ "master.seaweedfs.${self.data.site.domain}:443" ];
in
{
  imports = [
    ./options.nix
    ./security.nix
    ./s3.nix
    ./tmpfiles.nix
    ./master.nix
    ./volume.nix
    ./filer.nix
    ./admin.nix
    ./worker.nix
    ./proxy.nix
  ];

  config = mkMerge [
    (mkIf swLib.isIOPrimary {
      services.seaweedfs = {
        enable = true;

        master = {
          enable = true;
          peers = [ "none" ];
          volumeSizeLimitMB = 8192;
          # The HTTP API hands out file IDs and JWT write tokens unauthenticated.
          disableHttp = true;
        };

        volume = {
          enable = true;
          disk = "nvme";
          maxVolumes = 0;
          idxDir = "${swLib.baseDir}/idx";
          publicUrl = "volume.seaweedfs.${self.data.site.domain}";
          master = defaultMaster;
        };

        filer = {
          enable = true;
          master = defaultMaster;

          s3 = {
            enable = true;
            domainName = "s3.seaweedfs.${self.data.site.domain}";
            externalUrl = "https://s3.seaweedfs.${self.data.site.domain}";
          };
        };

        admin = {
          enable = true;
          master = defaultMaster;
        };

        worker = {
          enable = true;
          admin = "127.0.0.1:${toString cfg.admin.port}";
        };
      };
    })

    (mkIf (swLib.isEnabled && cfg.openFirewall) {
      networking.firewall.allowedTCPPorts = lib.flatten [
        (optional cfg.master.enable cfg.master.port)
        (optional cfg.master.enable cfg.master.grpcPort)

        (optional cfg.volume.enable cfg.volume.port)
        (optional cfg.volume.enable cfg.volume.grpcPort)
        (optional (cfg.volume.enable && cfg.volume.publicPort != null) cfg.volume.publicPort)

        (optional cfg.filer.enable cfg.filer.port)
        (optional cfg.filer.enable cfg.filer.grpcPort)
        (optional (cfg.filer.enable && cfg.filer.publicPort != null) cfg.filer.publicPort)

        (optional (cfg.filer.enable && cfg.filer.s3.enable) cfg.filer.s3.port)
        (optional (
          cfg.filer.enable && cfg.filer.s3.enable && cfg.filer.s3.grpcPort != null
        ) cfg.filer.s3.grpcPort)
        (optional (
          cfg.filer.enable && cfg.filer.s3.enable && cfg.filer.s3.httpsPort != null
        ) cfg.filer.s3.httpsPort)

        (optional (cfg.filer.enable && cfg.filer.webdav.enable) cfg.filer.webdav.port)

        (optional cfg.admin.enable cfg.admin.port)
        (optional (cfg.admin.enable && cfg.admin.grpcPort != null) cfg.admin.grpcPort)
        (optional (cfg.admin.enable && cfg.admin.legacyPort != null) cfg.admin.legacyPort)

        (optional (cfg.master.enable && cfg.master.metricsPort != null) cfg.master.metricsPort)
        (optional (cfg.volume.enable && cfg.volume.metricsPort != null) cfg.volume.metricsPort)
        (optional (cfg.filer.enable && cfg.filer.metricsPort != null) cfg.filer.metricsPort)
        (optional (cfg.admin.enable && cfg.admin.metricsPort != null) cfg.admin.metricsPort)
        (optional (cfg.worker.enable && cfg.worker.metricsPort != null) cfg.worker.metricsPort)
      ];
    })
  ];
}
