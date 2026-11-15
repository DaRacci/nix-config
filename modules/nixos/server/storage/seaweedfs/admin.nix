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

  adminFlags = {
    port = cfg.admin.port;
    "port.grpc" = cfg.admin.grpcPort;
    "port.legacy" = cfg.admin.legacyPort;
    ip = cfg.admin.ip;
    master = concatStringsSep "," cfg.admin.master;
    dataDir = cfg.admin.dataDir;
    filerGroup = if cfg.admin.filerGroup != "" then cfg.admin.filerGroup else null;
    urlPrefix = if cfg.admin.urlPrefix != "" then cfg.admin.urlPrefix else null;
    uploadMaxSizeMB = cfg.admin.uploadMaxSizeMB;
    metricsPort = cfg.admin.metricsPort;
    metricsIp = if cfg.admin.metricsIp != "" then cfg.admin.metricsIp else null;
  };
in
{
  options.services.seaweedfs.admin = swLib.mkComponentOptions {
    name = "admin";
    httpPort = 23646;
    grpcPort = 33646;
    grpcPortNullable = true;
    ipBind = false;
    dataDir = "${swLib.baseDir}/admin";
    metricsIp = "";
    extraOptions = {
      legacyPort = mkOption {
        type = nullOr port;
        default = null;
        description = "Admin legacy compatibility port.";
      };

      master = mkOption {
        type = listOf str;
        default = [ ];
        description = "Master addresses list.";
      };

      filerGroup = mkOption {
        type = str;
        default = "";
        description = "Filer group used by admin.";
      };

      urlPrefix = mkOption {
        type = str;
        default = "";
        description = "Admin URL prefix when reverse proxied under subpath.";
      };

      uploadMaxSizeMB = mkOption {
        type = nullOr ints.unsigned;
        default = null;
        description = "Max admin UI upload size in MB.";
      };
    };
  };

  config = mkMerge [
    (mkIf swLib.isEnabled {
      assertions = [
        {
          assertion = !cfg.admin.enable || cfg.admin.master != [ ];
          message = "services.seaweedfs.admin.master must not be empty when admin service is enabled.";
        }
      ];
    })

    (swLib.mkWeedService {
      component = "admin";
      description = "SeaweedFS Admin UI Server";
      flags = adminFlags;
      extraArgs = cfg.admin.extraArgs;
      workingDir = cfg.admin.dataDir;
    })
  ];
}
