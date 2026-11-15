{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    concatStringsSep
    mkIf
    mkMerge
    mkOption
    ;

  inherit (lib.types)
    enum
    ints
    listOf
    nullOr
    port
    str
    ;

  swLib = import ./lib.nix {
    inherit config lib;
  };

  cfg = config.services.seaweedfs;

  volumeFlags = {
    port = cfg.volume.port;
    "port.grpc" = cfg.volume.grpcPort;
    "port.public" = cfg.volume.publicPort;
    ip = cfg.volume.ip;
    "ip.bind" = if cfg.volume.ipBind != "" then cfg.volume.ipBind else null;
    dir = cfg.volume.dataDir;
    mserver = concatStringsSep "," cfg.volume.master;
    max = cfg.volume.maxVolumes;
    index = cfg.volume.index;
    readMode = cfg.volume.readMode;
    minFreeSpace = cfg.volume.minFreeSpace;
    fileSizeLimitMB = cfg.volume.fileSizeLimitMB;
    id = cfg.volume.id;
    publicUrl = cfg.volume.publicUrl;
    dataCenter = if cfg.volume.dataCenter != "" then cfg.volume.dataCenter else null;
    rack = if cfg.volume.rack != "" then cfg.volume.rack else null;
    disk = if cfg.volume.disk != "" then cfg.volume.disk else null;
    tags = cfg.volume.tags;
    "dir.idx" = cfg.volume.idxDir;
    metricsPort = cfg.volume.metricsPort;
    whiteList = if cfg.volume.whiteList != [ ] then concatStringsSep "," cfg.volume.whiteList else null;
  };
in
{
  options.services.seaweedfs.volume = swLib.mkComponentOptions {
    name = "volume";
    httpPort = 8080;
    grpcPort = 18080;
    dataDir = "${swLib.baseDir}/volume";
    extraOptions = {
      publicPort = mkOption {
        type = nullOr port;
        default = null;
        description = "Volume public HTTP port override.";
      };

      id = mkOption {
        type = nullOr str;
        default = null;
        description = "Volume server ID override.";
      };

      publicUrl = mkOption {
        type = nullOr str;
        default = null;
        description = "Publicly reachable volume URL for master/filer redirects.";
      };

      master = mkOption {
        type = listOf str;
        default = [ ];
        description = "Master addresses list.";
      };

      maxVolumes = mkOption {
        type = ints.unsigned;
        default = 8;
        description = "Max number of volumes.";
      };

      dataCenter = mkOption {
        type = str;
        default = "";
        description = "Volume data center label.";
      };

      rack = mkOption {
        type = str;
        default = "";
        description = "Volume rack label.";
      };

      disk = mkOption {
        type = str;
        default = "";
        description = "Volume disk type label.";
      };

      tags = mkOption {
        type = nullOr str;
        default = null;
        description = "Per-data-dir volume tags in weed format.";
      };

      idxDir = mkOption {
        type = nullOr str;
        default = null;
        description = "Directory for index files.";
      };

      index = mkOption {
        type = enum [
          "memory"
          "leveldb"
          "leveldbMedium"
          "leveldbLarge"
        ];
        default = "memory";
        description = "Needle map index backend.";
      };

      readMode = mkOption {
        type = enum [
          "local"
          "proxy"
          "redirect"
        ];
        default = "proxy";
        description = "Read behavior for non-local volumes.";
      };

      minFreeSpace = mkOption {
        type = str;
        default = "1";
        description = "Minimum free space threshold.";
      };

      fileSizeLimitMB = mkOption {
        type = ints.positive;
        default = 256;
        description = "Max file size handled by volume server.";
      };

      whiteList = mkOption {
        type = listOf str;
        default = [ ];
        description = "IPs allowed for write operations.";
      };
    };
  };

  config = mkMerge [
    (mkIf swLib.isEnabled {
      assertions = [
        {
          assertion = !cfg.volume.enable || cfg.volume.master != [ ];
          message = "services.seaweedfs.volume.master must not be empty when volume service is enabled.";
        }
      ];
    })

    (swLib.mkWeedService {
      component = "volume";
      description = "SeaweedFS Volume Server";
      flags = volumeFlags;
      extraArgs = cfg.volume.extraArgs;
      workingDir = cfg.volume.dataDir;
    })
  ];
}
