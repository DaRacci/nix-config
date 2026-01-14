{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.server.storage.bucketMounts;

  inherit (lib)
    toUpper
    mkOption
    mkIf
    mapAttrs
    mapAttrs'
    nameValuePair
    ;
  inherit (lib.types)
    attrsOf
    submodule
    str
    int
    ;
in
{
  options.server.storage.bucketMounts = mkOption {
    type = attrsOf (
      submodule (
        { name, ... }:
        {
          options = rec {
            bucketName = mkOption {
              type = str;
              default = name;
              description = "The name of the S3 bucket to mount.";
            };

            credentialsFile = mkOption {
              type = str;
              default = config.sops.secrets."S3FS_AUTH/${toUpper name}".path;
              description = "Path to the file containing the minio credentials.";
            };

            mountLocation = mkOption {
              type = str;
              description = "Path where the bucket should be mounted.";
              default = "/mnt/buckets/${bucketName}";
            };

            uid = mkOption {
              type = int;
              description = "User ID to own the mounted bucket.";
              default = null;
            };

            gid = mkOption {
              type = int;
              description = "Group ID to own the mounted bucket.";
              default = null;
            };

            umask = mkOption {
              type = int;
              description = "Umask for the mounted bucket.";
              default = 022;
            };
          };
        }
      )
    );
    default = [ ];
    description = ''
      A list of S3 bucket names to mount via s3fs-fuse.

      Each bucket will be mounted at /mnt/buckets/<bucket-name>.
    '';
  };

  config = mkIf (cfg != { }) {
    sops.secrets =
      cfg
      |> mapAttrs' (
        name: value:
        nameValuePair "S3FS_AUTH/${toUpper name}" {
          inherit (value) uid gid;
        }
      );

    environment.systemPackages = [ pkgs.s3fs ];

    programs.fuse.userAllowOther = true;

    fileSystems =
      cfg
      |> mapAttrs (
        name: bucketCfg: {
          device = "${lib.getExe' pkgs.s3fs "s3fs"}#${name}";
          mountPoint = bucketCfg.mountLocation;
          fsType = "fuse";
          noCheck = true;
          options = [
            "_netdev"
            "allow_other"
            "use_path_request_style"
            "url=https://minio.racci.dev"
            "passwd_file=${bucketCfg.credentialsFile}"
            "umask=${toString bucketCfg.umask}"
            "mp_umask=${toString bucketCfg.umask}"
            "nonempty"
            (lib.optionalString (bucketCfg.uid != null) "uid=${toString bucketCfg.uid}")
            (lib.optionalString (bucketCfg.gid != null) "gid=${toString bucketCfg.gid}")
          ];
        }
      );
  };
}
