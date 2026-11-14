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

  masterFlags = {
    port = cfg.master.port;
    "port.grpc" = cfg.master.grpcPort;
    ip = cfg.master.ip;
    mdir = cfg.master.dataDir;
    volumeSizeLimitMB = cfg.master.volumeSizeLimitMB;
    fileSizeLimitMB = cfg.master.fileSizeLimitMB;
    electionTimeout = cfg.master.electionTimeout;
    heartbeatInterval = cfg.master.heartbeatInterval;
    garbageThreshold = cfg.master.garbageThreshold;
    "telemetry.url" = cfg.master.telemetryUrl;
    maxParallelVacuumPerServer = cfg.master.maxParallelVacuum;
    "ip.bind" = if cfg.master.ipBind != "" then cfg.master.ipBind else null;
    volumePreallocate = if cfg.master.volumePreallocate then true else null;
    defaultReplication =
      if cfg.master.defaultReplication != "" then cfg.master.defaultReplication else null;
    metricsPort = cfg.master.metricsPort;
    peers = if cfg.master.peers != [ ] then concatStringsSep "," cfg.master.peers else null;
    whiteList = if cfg.master.whiteList != [ ] then concatStringsSep "," cfg.master.whiteList else null;
    disableHttp = if cfg.master.disableHttp then true else null;
    telemetry = if cfg.master.telemetry then null else "false";
  };
in
{
  config = swLib.mkWeedService {
    component = "master";
    description = "SeaweedFS Master Server";
    flags = masterFlags;
    extraArgs = cfg.master.extraArgs;
    workingDir = cfg.master.dataDir;
    needsMaster = false;
  };
}
