{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    mkIf
    mkMerge
    optional
    getExe
    escapeShellArgs
    ;

  cfg = config.services.seaweedfs;

  baseDir = "/var/lib/seaweedfs";
  isIOPrimary = config.server.ioPrimaryHost == config.networking.hostName;
  isEnabled = cfg.enable && isIOPrimary;

  grpcTLSServices = [
    "MASTER"
    "VOLUME"
    "FILER"
    "CLIENT"
    "ADMIN"
    "WORKER"
  ];

  mkCommonSystemdService =
    {
      needsMaster ? true,
      extraConfig,
    }:
    mkMerge [
      {
        after = [
          "network-online.target"
        ]
        ++ optional (needsMaster && cfg.master.enable) "seaweedfs-master.service";
        wants = [ "network-online.target" ];
        requires = optional (needsMaster && cfg.master.enable) "seaweedfs-master.service";
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

  weedOptionFormat = optionName: {
    option = "-${optionName}";
    sep = "=";
    explicitBool = false;
    formatArg = toString;
  };

  mkWeedCommand =
    component: flags: extraArgs:
    escapeShellArgs (
      [
        (getExe cfg.package)
        component
      ]
      ++ lib.cli.toCommandLine weedOptionFormat flags
      ++ extraArgs
    );

  mkWeedService =
    {
      component,
      description,
      flags,
      extraArgs ? [ ],
      workingDir,
      needsMaster ? true,
      after ? [ ],
      wants ? [ ],
    }:
    mkIf (isEnabled && cfg.${component}.enable) {
      systemd.services."seaweedfs-${component}" = mkCommonSystemdService {
        inherit needsMaster;
        extraConfig = {
          inherit description after wants;
          serviceConfig = {
            ExecStart = mkWeedCommand component flags extraArgs;
            inherit workingDir;
          };
        };
      };
    };
in
{
  inherit
    cfg
    baseDir
    isIOPrimary
    isEnabled
    grpcTLSServices
    mkCommonSystemdService
    mkWeedCommand
    mkWeedService
    ;
}
