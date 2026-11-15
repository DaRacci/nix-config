{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    concatStringsSep
    mkOption
    ;

  inherit (lib.types)
    bool
    float
    ints
    listOf
    str
    ;

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
  options.services.seaweedfs.master = swLib.mkComponentOptions {
    name = "master";
    httpPort = 9333;
    grpcPort = 19333;
    dataDir = "${swLib.baseDir}/master";
    extraOptions = {
      peers = mkOption {
        type = listOf str;
        default = [ ];
        description = "Master peers list.";
      };

      volumeSizeLimitMB = mkOption {
        type = ints.positive;
        default = 30000;
        description = "Stop directing writes to oversized volumes.";
      };

      fileSizeLimitMB = mkOption {
        type = ints.positive;
        default = 256;
        description = "Limit max file size accepted by master submit path.";
      };

      volumePreallocate = mkOption {
        type = bool;
        default = false;
        description = "Preallocate disk space for volumes.";
      };

      defaultReplication = mkOption {
        type = str;
        default = "";
        description = "Default replication type.";
      };

      electionTimeout = mkOption {
        type = str;
        default = "10s";
        description = "Master election timeout.";
      };

      heartbeatInterval = mkOption {
        type = str;
        default = "300ms";
        description = "Master heartbeat interval.";
      };

      garbageThreshold = mkOption {
        type = float;
        default = 0.3;
        description = "Vacuum garbage threshold.";
      };

      whiteList = mkOption {
        type = listOf str;
        default = [ ];
        description = "IPs allowed for write operations.";
      };

      disableHttp = mkOption {
        type = bool;
        default = false;
        description = "Disable master HTTP API and only allow gRPC.";
      };

      telemetry = mkOption {
        type = bool;
        default = true;
        description = "Enable anonymous telemetry.";
      };

      telemetryUrl = mkOption {
        type = str;
        default = "https://telemetry.seaweedfs.com/api/collect";
        description = "Telemetry endpoint URL.";
      };

      maxParallelVacuum = mkOption {
        type = ints.positive;
        default = 1;
        description = "Max parallel vacuum operations per volume server.";
      };
    };
  };

  config = swLib.mkWeedService {
    component = "master";
    description = "SeaweedFS Master Server";
    flags = masterFlags;
    extraArgs = cfg.master.extraArgs;
    workingDir = cfg.master.dataDir;
    needsMaster = false;
  };
}
