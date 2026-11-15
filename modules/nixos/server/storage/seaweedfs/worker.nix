{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    mkIf
    mkMerge
    mkOption
    ;

  inherit (lib.types)
    ints
    nullOr
    str
    ;

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
  options.services.seaweedfs.worker = swLib.mkComponentOptions {
    name = "worker";
    ip = null;
    ipBind = false;
    metricsIp = "0.0.0.0";
    extraOptions = {
      admin = mkOption {
        type = str;
        default = "127.0.0.1:23646";
        description = "Admin server address used by worker.";
      };

      id = mkOption {
        type = nullOr str;
        default = null;
        description = "Worker ID.";
      };

      workingDir = mkOption {
        type = str;
        default = "${swLib.baseDir}/worker";
        description = "Worker state directory.";
      };

      jobType = mkOption {
        type = str;
        default = "vacuum,volume_balance,erasure_coding,admin_script";
        description = "Worker job type list.";
      };

      heartbeat = mkOption {
        type = str;
        default = "15s";
        description = "Worker heartbeat interval.";
      };

      reconnect = mkOption {
        type = str;
        default = "5s";
        description = "Worker reconnect delay.";
      };

      maxDetect = mkOption {
        type = ints.positive;
        default = 1;
        description = "Max concurrent detect requests.";
      };

      maxExecute = mkOption {
        type = ints.positive;
        default = 4;
        description = "Max concurrent execute requests.";
      };

      address = mkOption {
        type = nullOr str;
        default = null;
        description = "Worker advertised address override.";
      };
    };
  };

  config = mkMerge [
    (mkIf swLib.isEnabled {
      assertions = [
        {
          assertion = !cfg.worker.enable || cfg.worker.admin != "";
          message = "services.seaweedfs.worker.admin must not be empty when worker service is enabled.";
        }
      ];
    })

    (swLib.mkWeedService {
      component = "worker";
      description = "SeaweedFS Worker Server";
      flags = workerFlags;
      extraArgs = cfg.worker.extraArgs;
      workingDir = cfg.worker.workingDir;
      after = [ "seaweedfs-admin.service" ];
      wants = [ "seaweedfs-admin.service" ];
    })
  ];
}
