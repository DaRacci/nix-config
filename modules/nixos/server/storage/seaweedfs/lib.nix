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

  mkComponentOptions =
    {
      name,
      httpPort ? null,
      grpcPort ? null,
      grpcPortNullable ? false,
      ip ? "127.0.0.1",
      ipBind ? true,
      dataDir ? null,
      metricsPort ? true,
      metricsIp ? null,
      extraArgs ? true,
      extraOptions ? { },
    }:
    {
      enable = lib.mkEnableOption "SeaweedFS ${name} service";
    }
    // lib.optionalAttrs (httpPort != null) {
      port = lib.mkOption {
        type = lib.types.port;
        default = httpPort;
        description = "${name} HTTP listen port.";
      };
    }
    // lib.optionalAttrs (grpcPort != null || grpcPortNullable) {
      grpcPort = lib.mkOption {
        type = if grpcPortNullable then lib.types.nullOr lib.types.port else lib.types.port;
        default = grpcPort;
        description = "${name} gRPC listen port.";
      };
    }
    // lib.optionalAttrs (ip != null) {
      ip = lib.mkOption {
        type = lib.types.str;
        default = ip;
        description = "${name} advertised IP or hostname.";
      };
    }
    // lib.optionalAttrs (ip != null && ipBind) {
      ipBind = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "${name} bind IP. Empty uses ip.";
      };
    }
    // lib.optionalAttrs (dataDir != null) {
      dataDir = lib.mkOption {
        type = lib.types.str;
        default = dataDir;
        description = "${name} data directory.";
      };
    }
    // lib.optionalAttrs metricsPort {
      metricsPort = lib.mkOption {
        type = lib.types.nullOr lib.types.port;
        default = null;
        description = "${name} metrics port.";
      };
    }
    // lib.optionalAttrs (metricsIp != null) {
      metricsIp = lib.mkOption {
        type = lib.types.str;
        default = metricsIp;
        description = "${name} metrics bind IP.";
      };
    }
    // lib.optionalAttrs extraArgs {
      extraArgs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Extra CLI args passed to weed ${name}.";
      };
    }
    // extraOptions;

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
    mkComponentOptions
    mkCommonSystemdService
    mkWeedCommand
    mkWeedService
    ;
}
