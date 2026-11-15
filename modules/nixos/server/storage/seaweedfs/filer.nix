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
    optionals
    ;

  inherit (lib.types)
    bool
    ints
    lines
    listOf
    nullOr
    port
    str
    ;

  swLib = import ./lib.nix {
    inherit config lib;
  };

  cfg = config.services.seaweedfs;

  s3Flags =
    if !cfg.filer.s3.enable then
      { }
    else
      {
        s3 = true;
        "s3.port" = cfg.filer.s3.port;
        "s3.port.grpc" = cfg.filer.s3.grpcPort;
        "s3.port.https" = cfg.filer.s3.httpsPort;
        "s3.allowDeleteBucketNotEmpty" = if cfg.filer.s3.allowDeleteBucketNotEmpty then true else null;
        "s3.allowEmptyFolder" = if cfg.filer.s3.allowEmptyFolder then null else "false";
        "s3.allowedOrigins" =
          if cfg.filer.s3.allowedOrigins != "*" then cfg.filer.s3.allowedOrigins else null;
        "s3.domainName" = cfg.filer.s3.domainName;
        "s3.dataCenter" = if cfg.filer.s3.dataCenter != "" then cfg.filer.s3.dataCenter else null;
        "s3.cert.file" = cfg.filer.s3.cert.file;
        "s3.key.file" = cfg.filer.s3.cert.key;
        "s3.auditLogConfig" = cfg.filer.s3.auditLogConfig;
        "s3.config" = cfg.filer.s3.configFile;
        "s3.externalUrl" = cfg.filer.s3.externalUrl;
      };

  webdavFlags =
    if !cfg.filer.webdav.enable then
      { }
    else
      {
        webdav = true;
        "webdav.port" = cfg.filer.webdav.port;
        "webdav.filer.path" = cfg.filer.webdav.path;
        "webdav.cacheDir" = cfg.filer.webdav.cacheDir;
        "webdav.cacheCapacityMB" = cfg.filer.webdav.cacheCapacityMB;
        "webdav.collection" =
          if cfg.filer.webdav.collection != "" then cfg.filer.webdav.collection else null;
        "webdav.disk" = if cfg.filer.webdav.disk != "" then cfg.filer.webdav.disk else null;
        "webdav.replication" =
          if cfg.filer.webdav.replication != "" then cfg.filer.webdav.replication else null;
      };

  filerFlags = {
    port = cfg.filer.port;
    "port.grpc" = cfg.filer.grpcPort;
    "port.readonly" = cfg.filer.publicPort;
    ip = cfg.filer.ip;
    "ip.bind" = if cfg.filer.ipBind != "" then cfg.filer.ipBind else null;
    master = concatStringsSep "," cfg.filer.master;
    defaultStoreDir = cfg.filer.dataDir;
    maxMB = cfg.filer.maxMB;
    allowedOrigins = cfg.filer.allowedOrigins;
    exposeDirectoryData = builtins.toJSON cfg.filer.exposeDirectoryData;
    collection = if cfg.filer.collection != "" then cfg.filer.collection else null;
    defaultReplicaPlacement =
      if cfg.filer.defaultReplicaPlacement != "" then cfg.filer.defaultReplicaPlacement else null;
    metricsPort = cfg.filer.metricsPort;
    disableHttp = if cfg.filer.disableHttp then true else null;
  };
in
{
  options.services.seaweedfs.filer = swLib.mkComponentOptions {
    name = "filer";
    httpPort = 8888;
    grpcPort = 18888;
    dataDir = "${swLib.baseDir}/filer";
    extraOptions = {
      publicPort = mkOption {
        type = nullOr port;
        default = null;
        description = "Filer readonly public port override.";
      };

      collection = mkOption {
        type = str;
        default = "";
        description = "Default filer collection.";
      };

      defaultReplicaPlacement = mkOption {
        type = str;
        default = "";
        description = "Default filer replica placement.";
      };

      master = mkOption {
        type = listOf str;
        default = [ ];
        description = "Master addresses list.";
      };

      maxMB = mkOption {
        type = ints.positive;
        default = 4;
        description = "Split files larger than this size.";
      };

      disableHttp = mkOption {
        type = bool;
        default = false;
        description = "Disable filer HTTP API and only allow gRPC.";
      };

      allowedOrigins = mkOption {
        type = str;
        default = "*";
        description = "CORS allowed origins.";
      };

      exposeDirectoryData = mkOption {
        type = bool;
        default = true;
        description = "Expose directory metadata in filer UI.";
      };

      tomlConfig = mkOption {
        type = nullOr lines;
        default = null;
        description = "Direct TOML content for filer.toml.";
      };

      webdav = swLib.mkComponentOptions {
        name = "webdav";
        httpPort = 7333;
        ip = null;
        ipBind = false;
        metricsPort = false;
        extraOptions = {
          path = mkOption {
            type = str;
            default = "/";
            description = "Remote filer path exposed over WebDAV.";
          };

          collection = mkOption {
            type = str;
            default = "";
            description = "WebDAV collection name.";
          };

          cacheDir = mkOption {
            type = str;
            default = "${swLib.baseDir}/webdav-cache";
            description = "WebDAV local cache directory.";
          };

          cacheCapacityMB = mkOption {
            type = ints.positive;
            default = 1000;
            description = "WebDAV cache size in MB.";
          };

          disk = mkOption {
            type = str;
            default = "";
            description = "WebDAV disk type label.";
          };

          replication = mkOption {
            type = str;
            default = "";
            description = "WebDAV replication strategy.";
          };
        };
      };
    };
  };

  config = mkMerge [
    (mkIf swLib.isEnabled {
      assertions = [
        {
          assertion = !cfg.filer.enable || cfg.filer.master != [ ];
          message = "services.seaweedfs.filer.master must not be empty when filer service is enabled.";
        }
      ];
    })

    (swLib.mkWeedService {
      component = "filer";
      description = "SeaweedFS Filer Server";
      flags = filerFlags // s3Flags // webdavFlags;
      extraArgs =
        optionals cfg.filer.s3.enable cfg.filer.s3.extraArgs
        ++ optionals cfg.filer.webdav.enable cfg.filer.webdav.extraArgs
        ++ cfg.filer.extraArgs;
      workingDir = cfg.filer.dataDir;
    })
  ];
}
