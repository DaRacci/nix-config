{
  config,
  lib,
  ...
}:
let
  inherit (lib) concatStringsSep;

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
  config = swLib.mkWeedService {
    component = "admin";
    description = "SeaweedFS Admin UI Server";
    flags = adminFlags;
    extraArgs = cfg.admin.extraArgs;
    workingDir = cfg.admin.dataDir;
  };
}
