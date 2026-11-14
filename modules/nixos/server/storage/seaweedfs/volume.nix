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

  volumeFlags = {
    port = cfg.volume.port;
    "port.grpc" = cfg.volume.grpcPort;
    "port.public" = cfg.volume.publicPort;
    ip = cfg.volume.ip;
    "ip.bind" = if cfg.volume.ipBind != "" then cfg.volume.ipBind else null;
    dir = cfg.volume.dataDir;
    mserver = concatStringsSep "," cfg.volume.master;
    max = cfg.volume.maxVolumes;
    index = cfg.volume.index;
    readMode = cfg.volume.readMode;
    minFreeSpace = cfg.volume.minFreeSpace;
    fileSizeLimitMB = cfg.volume.fileSizeLimitMB;
    id = cfg.volume.id;
    publicUrl = cfg.volume.publicUrl;
    dataCenter = if cfg.volume.dataCenter != "" then cfg.volume.dataCenter else null;
    rack = if cfg.volume.rack != "" then cfg.volume.rack else null;
    disk = if cfg.volume.disk != "" then cfg.volume.disk else null;
    tags = cfg.volume.tags;
    "dir.idx" = cfg.volume.idxDir;
    metricsPort = cfg.volume.metricsPort;
    whiteList = if cfg.volume.whiteList != [ ] then concatStringsSep "," cfg.volume.whiteList else null;
  };
in
{
  config = swLib.mkWeedService {
    component = "volume";
    description = "SeaweedFS Volume Server";
    flags = volumeFlags;
    extraArgs = cfg.volume.extraArgs;
    workingDir = cfg.volume.dataDir;
  };
}
