{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (builtins)
    all
    any
    length
    listToAttrs
    ;

  inherit (lib)
    concatLists
    concatMapStringsSep
    escapeShellArg
    escapeShellArgs
    filterAttrs
    getExe
    getExe'
    literalExpression
    mapAttrs
    mapAttrs'
    mapAttrsToList
    mkIf
    mkMerge
    mkOption
    nameValuePair
    optional
    optionalString
    toUpper
    unique
    ;

  inherit (lib.types)
    attrsOf
    bool
    enum
    int
    listOf
    nullOr
    str
    submodule
    ;

  cfg = config.server.storage.swfsMount;

  formatUmask =
    umask:
    let
      value = toString umask;
    in
    if umask < 10 then
      "00${value}"
    else if umask < 100 then
      "0${value}"
    else
      value;

  mkMountUnitName = name: "swfs-mount-${name}";
  mkHealthUnitName = name: "swfs-mount-health-${name}";

  anyMounts = cfg != { };
  anyMinioMounts = any (mountCfg: mountCfg.backend == "minio") (
    mapAttrsToList (_: mountCfg: mountCfg) cfg
  );
  anySeaweedMounts = any (mountCfg: mountCfg.backend == "seaweedfs") (
    mapAttrsToList (_: mountCfg: mountCfg) cfg
  );

  effectiveMinioCredentialsFile =
    name: mountCfg:
    if mountCfg.minio.credentialsFile != null then
      mountCfg.minio.credentialsFile
    else
      config.sops.secrets."S3FS_AUTH/${toUpper name}".path;

  effectiveRestartServices =
    mountCfg: unique (mountCfg.requiredByServices ++ mountCfg.healthCheck.restartServices);

  mkPrepareScript =
    name: mountCfg:
    pkgs.writeShellApplication {
      name = "${mkMountUnitName name}-prepare";
      runtimeInputs = with pkgs; [
        coreutils
      ];
      text = ''
        set -euo pipefail

        install -d -m 0755 ${escapeShellArg mountCfg.mountLocation}
        ${optionalString (mountCfg.uid != null && mountCfg.gid != null)
          "chown ${toString mountCfg.uid}:${toString mountCfg.gid} ${escapeShellArg mountCfg.mountLocation}"
        }
        ${optionalString (
          mountCfg.uid != null && mountCfg.gid == null
        ) "chown ${toString mountCfg.uid} ${escapeShellArg mountCfg.mountLocation}"}
        ${optionalString (
          mountCfg.uid == null && mountCfg.gid != null
        ) "chgrp ${toString mountCfg.gid} ${escapeShellArg mountCfg.mountLocation}"}
      '';
    };

  mkStopScript =
    name: mountCfg:
    pkgs.writeShellApplication {
      name = "${mkMountUnitName name}-stop";
      runtimeInputs = with pkgs; [
        fuse3
        util-linux
      ];
      text = ''
        set -euo pipefail

        if mountpoint -q ${escapeShellArg mountCfg.mountLocation}; then
          fusermount3 -u ${escapeShellArg mountCfg.mountLocation} 2>/dev/null \
            || fusermount -uz ${escapeShellArg mountCfg.mountLocation} 2>/dev/null \
            || umount -l ${escapeShellArg mountCfg.mountLocation} 2>/dev/null \
            || true
        fi
      '';
    };

  mkMountScript =
    name: mountCfg:
    let
      commonRuntimeInputs = with pkgs; [
        coreutils
      ];
      mountCommand =
        if mountCfg.backend == "minio" then
          "${getExe' pkgs.s3fs "s3fs"} ${escapeShellArgs minioArgs}"
        else
          "${getExe' config.services.seaweedfs.package "weed"} ${escapeShellArgs seaweedArgs}";

      minioArgs = [
        mountCfg.minio.bucketName
        mountCfg.mountLocation
        "-f"
        "-o"
        "allow_other"
        "-o"
        "use_path_request_style"
        "-o"
        "url=${mountCfg.minio.endpoint}"
        "-o"
        "passwd_file=${effectiveMinioCredentialsFile name mountCfg}"
        "-o"
        "umask=${formatUmask mountCfg.umask}"
        "-o"
        "mp_umask=${formatUmask mountCfg.umask}"
        "-o"
        "nonempty"
      ]
      ++ optional (mountCfg.uid != null) "-o"
      ++ optional (mountCfg.uid != null) "uid=${toString mountCfg.uid}"
      ++ optional (mountCfg.gid != null) "-o"
      ++ optional (mountCfg.gid != null) "gid=${toString mountCfg.gid}"
      ++ concatLists (
        map (value: [
          "-o"
          value
        ]) mountCfg.minio.extraOptions
      );

      seaweedArgs = [
        "mount"
        "-filer=${mountCfg.seaweedfs.filer}"
        "-filer.path=${mountCfg.seaweedfs.filerPath}"
        "-dir=${mountCfg.mountLocation}"
        "-dirAutoCreate=${if mountCfg.seaweedfs.dirAutoCreate then "true" else "false"}"
        "-allowOthers=${if mountCfg.seaweedfs.allowOthers then "true" else "false"}"
        "-readOnly=${if mountCfg.seaweedfs.readOnly then "true" else "false"}"
        "-umask=${formatUmask mountCfg.umask}"
        "-metadataFlushSeconds=${toString mountCfg.seaweedfs.metadataFlushSeconds}"
      ]
      ++ optional (mountCfg.seaweedfs.uidMap != null) "-map.uid=${mountCfg.seaweedfs.uidMap}"
      ++ optional (mountCfg.seaweedfs.gidMap != null) "-map.gid=${mountCfg.seaweedfs.gidMap}"
      ++ optional (
        mountCfg.seaweedfs.writeBufferSizeMB != null
      ) "-writeBufferSizeMB=${toString mountCfg.seaweedfs.writeBufferSizeMB}"
      ++ mountCfg.seaweedfs.extraArgs;
    in
    pkgs.writeShellApplication {
      name = mkMountUnitName name;
      runtimeInputs =
        commonRuntimeInputs
        ++ (if mountCfg.backend == "minio" then [ pkgs.s3fs ] else [ config.services.seaweedfs.package ]);
      text = ''
        set -euo pipefail

        exec ${mountCommand}
      '';
    };

  mkHealthScript =
    name: mountCfg:
    let
      restartServices = effectiveRestartServices mountCfg;
    in
    pkgs.writeShellApplication {
      name = "${mkHealthUnitName name}-check";
      runtimeInputs = with pkgs; [
        coreutils
        fuse3
        systemd
        util-linux
      ];
      text = ''
        set -euo pipefail

        mount_path=${escapeShellArg mountCfg.mountLocation}
        timeout_window=${escapeShellArg mountCfg.healthCheck.timeout}

        if mountpoint -q "$mount_path" && timeout --foreground "$timeout_window" stat "$mount_path" >/dev/null 2>&1; then
          exit 0
        fi

        fusermount3 -u "$mount_path" 2>/dev/null \
          || fusermount -uz "$mount_path" 2>/dev/null \
          || umount -l "$mount_path" 2>/dev/null \
          || true

        systemctl restart ${escapeShellArg "${mkMountUnitName name}.service"}

        ${concatMapStringsSep "\n" (
          serviceName: "systemctl restart ${escapeShellArg serviceName}"
        ) restartServices}
      '';
    };

  mountServices =
    cfg
    |> mapAttrs' (
      name: mountCfg:
      nameValuePair (mkMountUnitName name) {
        description = "Storage mount ${name}";
        wantedBy = [ "multi-user.target" ];
        wants = [ "network-online.target" ];
        requires = [ "network-online.target" ];
        after = [ "network-online.target" ];
        serviceConfig = {
          Type = "simple";
          ExecStartPre = getExe (mkPrepareScript name mountCfg);
          ExecStart = getExe (mkMountScript name mountCfg);
          ExecStop = getExe (mkStopScript name mountCfg);
          KillMode = "control-group";
          Restart = "always";
          RestartSec = "45s";
          TimeoutStopSec = "90s";
        };
      }
    );

  healthServices =
    cfg
    |> filterAttrs (_: mountCfg: mountCfg.healthCheck.enable)
    |> mapAttrs' (
      name: mountCfg:
      nameValuePair (mkHealthUnitName name) {
        description = "Health check for storage mount ${name}";
        after = [ "${mkMountUnitName name}.service" ];
        requires = [ "${mkMountUnitName name}.service" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = getExe (mkHealthScript name mountCfg);
        };
      }
    );

  healthTimers =
    cfg
    |> filterAttrs (_: mountCfg: mountCfg.healthCheck.enable)
    |> mapAttrs (
      name: mountCfg: {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          Persistent = true;
          OnActiveSec = mountCfg.healthCheck.interval;
          OnUnitActiveSec = mountCfg.healthCheck.interval;
          Unit = "${mkHealthUnitName name}.service";
        };
      }
    );

  dependentServiceConfig =
    cfg
    |> mapAttrsToList (
      name: mountCfg:
      listToAttrs (
        map (
          serviceName:
          nameValuePair serviceName {
            after = [ "${mkMountUnitName name}.service" ];
            requires = [ "${mkMountUnitName name}.service" ];
          }
        ) mountCfg.requiredByServices
      )
    )
    |> mkMerge;

  mountLocations = mapAttrsToList (_: mountCfg: mountCfg.mountLocation) cfg;
in
{
  options.server.storage.swfsMount = mkOption {
    type = attrsOf (
      submodule (
        { name, ... }:
        {
          options = {
            backend = mkOption {
              type = enum [
                "minio"
                "seaweedfs"
              ];
              description = "The storage backend to mount.";
            };

            mountLocation = mkOption {
              type = str;
              default = "/mnt/storage/${name}";
              defaultText = literalExpression ''
                "/mnt/storage/''${name}"
              '';
              description = "Path where the backend should be mounted.";
            };

            uid = mkOption {
              type = nullOr int;
              default = null;
              description = "User ID that should own the mounted path.";
            };

            gid = mkOption {
              type = nullOr int;
              default = null;
              description = "Group ID that should own the mounted path.";
            };

            umask = mkOption {
              type = int;
              default = 22;
              description = "Umask applied to files and directories inside the mount.";
            };

            requiredByServices = mkOption {
              type = listOf str;
              default = [ ];
              description = "Systemd services that must wait for this mount before starting.";
            };

            healthCheck = {
              enable = mkOption {
                type = bool;
                default = true;
                description = "Whether to monitor this mount and attempt automated recovery.";
              };

              interval = mkOption {
                type = str;
                default = "15min";
                description = "Systemd timer interval between mount health probes.";
              };

              timeout = mkOption {
                type = str;
                default = "30s";
                description = "Timeout applied to the mount health probe.";
              };

              restartServices = mkOption {
                type = listOf str;
                default = [ ];
                description = "Additional systemd services to restart after recovering this mount.";
              };
            };

            minio = {
              bucketName = mkOption {
                type = str;
                default = name;
                description = "The MinIO bucket to mount with s3fs.";
              };

              credentialsFile = mkOption {
                type = nullOr str;
                default = null;
                description = ''
                  Path to the MinIO credentials file in `ACCESS_KEY_ID:SECRET_ACCESS_KEY` format.

                  When left null, the module provisions and uses the `S3FS_AUTH/<NAME_IN_UPPERCASE>` sops secret.
                '';
              };

              endpoint = mkOption {
                type = str;
                default = "https://minio.racci.dev";
                description = "The S3-compatible MinIO endpoint used by s3fs.";
              };

              extraOptions = mkOption {
                type = listOf str;
                default = [ ];
                description = "Additional `-o` options passed to s3fs.";
              };
            };

            seaweedfs = {
              filer = mkOption {
                type = str;
                default = "";
                description = "SeaweedFS filer address in host:port form.";
              };

              filerPath = mkOption {
                type = str;
                default = "/";
                description = "Remote filer path to expose through the mount.";
              };

              dirAutoCreate = mkOption {
                type = bool;
                default = true;
                description = "Whether `weed mount` should create the mount directory when needed.";
              };

              allowOthers = mkOption {
                type = bool;
                default = true;
                description = "Whether to allow non-owning users to access the SeaweedFS mount.";
              };

              readOnly = mkOption {
                type = bool;
                default = false;
                description = "Whether the SeaweedFS mount should be read-only.";
              };

              metadataFlushSeconds = mkOption {
                type = int;
                default = 120;
                description = "How often `weed mount` flushes metadata to the filer.";
              };

              writeBufferSizeMB = mkOption {
                type = nullOr int;
                default = null;
                description = "Optional write buffer cap passed to `weed mount` in megabytes.";
              };

              uidMap = mkOption {
                type = nullOr str;
                default = null;
                description = "Optional local-to-filer UID mapping string for `weed mount`.";
              };

              gidMap = mkOption {
                type = nullOr str;
                default = null;
                description = "Optional local-to-filer GID mapping string for `weed mount`.";
              };

              extraArgs = mkOption {
                type = listOf str;
                default = [ ];
                description = "Additional arguments passed directly to `weed mount`.";
              };
            };
          };
        }
      )
    );
    default = { };
    description = ''
      Declarative storage mounts backed by MinIO or SeaweedFS.

      Each entry creates a systemd-managed FUSE mount service plus an optional health-check timer.
    '';
  };

  config = mkIf anyMounts {
    assertions = [
      {
        assertion = length mountLocations == length (unique mountLocations);
        message = "server.storage.swfsMount entries must use unique mountLocation values.";
      }
      {
        assertion = all (mountCfg: mountCfg.backend != "seaweedfs" || mountCfg.seaweedfs.filer != "") (
          mapAttrsToList (_: mountCfg: mountCfg) cfg
        );
        message = "SeaweedFS mounts must set server.storage.swfsMount.<name>.seaweedfs.filer.";
      }
    ];

    sops.secrets =
      cfg
      |> filterAttrs (_: mountCfg: mountCfg.backend == "minio" && mountCfg.minio.credentialsFile == null)
      |> mapAttrs' (
        name: mountCfg:
        nameValuePair "S3FS_AUTH/${toUpper name}" (
          filterAttrs (_: value: value != null) {
            inherit (mountCfg) uid gid;
          }
        )
      );

    environment.systemPackages =
      optional anyMinioMounts pkgs.s3fs ++ optional anySeaweedMounts config.services.seaweedfs.package;

    programs.fuse.userAllowOther = true;

    systemd = {
      services = mkMerge [
        mountServices
        healthServices
        dependentServiceConfig
      ];
      timers = healthTimers;
    };
  };
}
