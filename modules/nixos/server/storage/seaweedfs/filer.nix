{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    concatStringsSep
    optionals
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
        "s3.config" = cfg.filer.s3.config;
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
  config = swLib.mkWeedService {
    component = "filer";
    description = "SeaweedFS Filer Server";
    flags = filerFlags // s3Flags // webdavFlags;
    extraArgs =
      optionals cfg.filer.s3.enable cfg.filer.s3.extraArgs
      ++ optionals cfg.filer.webdav.enable cfg.filer.webdav.extraArgs
      ++ cfg.filer.extraArgs;
    workingDir = cfg.filer.dataDir;
  };
}
