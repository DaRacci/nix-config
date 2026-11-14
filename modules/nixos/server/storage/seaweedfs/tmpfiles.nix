{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    mkIf
    mkMerge
    toUpper
    ;

  swLib = import ./lib.nix {
    inherit config lib;
  };

  cfg = config.services.seaweedfs;

  mkDir = path: {
    "${path}".d = {
      mode = "0755";
      user = "seaweedfs";
      group = "seaweedfs";
    };
  };

  mkSecurityLink = path: security: {
    "${path}/security.toml"."L+" = {
      mode = "0600";
      user = "seaweedfs";
      group = "seaweedfs";
      argument = config.sops.templates."SEAWEEDFS/SECURITY/${toUpper security}".path;
    };
  };

  mkDirAndSecurity = path: security: mkDir path // mkSecurityLink path security;

  mkServiceDir =
    {
      component,
      path,
      security,
    }:
    mkIf cfg.${component}.enable {
      "seaweedfs-${component}" = mkDirAndSecurity path security;
    };
in
{
  config = mkIf swLib.isEnabled {
    users.users.seaweedfs = {
      isSystemUser = true;
      group = "seaweedfs";
      home = swLib.baseDir;
      createHome = true;
    };

    users.groups.seaweedfs = { };

    systemd.tmpfiles.settings = mkMerge [
      {
        seaweedfs-base = mkDir swLib.baseDir;
      }

      (mkServiceDir {
        component = "master";
        path = cfg.master.dataDir;
        security = "master";
      })

      (mkServiceDir {
        component = "volume";
        path = cfg.volume.dataDir;
        security = "master";
      })

      (mkServiceDir {
        component = "filer";
        path = cfg.filer.dataDir;
        security = "filer";
      })

      (mkServiceDir {
        component = "admin";
        path = cfg.admin.dataDir;
        security = "master";
      })

      (mkServiceDir {
        component = "worker";
        path = cfg.worker.workingDir;
        security = "master";
      })

      (mkIf (cfg.filer.enable && cfg.filer.webdav.enable) {
        seaweedfs-webdav = mkDir cfg.filer.webdav.cacheDir;
      })

      (mkIf (cfg.volume.enable && cfg.volume.idxDir != null) {
        seaweedfs-idx = mkDir cfg.volume.idxDir;
      })

      (mkIf (cfg.filer.enable && cfg.filer.tomlConfig != null) {
        seaweedfs-config = mkDir "${swLib.baseDir}/.seaweedfs" // {
          "${swLib.baseDir}/.seaweedfs/filer.toml"."f+" = {
            mode = "0644";
            user = "seaweedfs";
            group = "seaweedfs";
            argument = cfg.filer.tomlConfig;
          };
        };
      })
    ];
  };
}
