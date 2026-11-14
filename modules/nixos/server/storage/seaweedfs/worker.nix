{
  config,
  lib,
  ...
}:
let
  swLib = import ./lib.nix {
    inherit config lib;
  };

  cfg = config.services.seaweedfs;

  workerFlags = {
    admin = cfg.worker.admin;
    jobType = cfg.worker.jobType;
    workingDir = cfg.worker.workingDir;
    heartbeat = cfg.worker.heartbeat;
    reconnect = cfg.worker.reconnect;
    maxDetect = cfg.worker.maxDetect;
    maxExecute = cfg.worker.maxExecute;
    metricsIp = cfg.worker.metricsIp;
    id = cfg.worker.id;
    address = cfg.worker.address;
    metricsPort = cfg.worker.metricsPort;
  };
in
{
  config = swLib.mkWeedService {
    component = "worker";
    description = "SeaweedFS Worker Server";
    flags = workerFlags;
    extraArgs = cfg.worker.extraArgs;
    workingDir = cfg.worker.workingDir;
    after = [ "seaweedfs-admin.service" ];
    wants = [ "seaweedfs-admin.service" ];
  };
}
