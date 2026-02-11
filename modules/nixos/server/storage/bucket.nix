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
    literalExpression
    ;
  inherit (lib.types)
    attrsOf
    submodule
    str
    int
    nullOr
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
              default =
                let
                  secretName = "S3FS_AUTH/${toUpper name}";
                in
                if config.sops.secrets ? "${secretName}" then config.sops.secrets."${secretName}".path else "";
              defaultText = literalExpression ''
                let
                  secretName = "S3FS_AUTH/''${toUpper name}";
                in
                if config.sops.secrets ? "''${secretName}" then config.sops.secrets."''${secretName}".path else "";
              '';
              description = "Path to the file containing the minio credentials.";
            };

            mountLocation = mkOption {
              type = str;
              description = "Path where the bucket should be mounted.";
              default = "/mnt/buckets/${bucketName}";
              defaultText = literalExpression ''
                "/mnt/buckets/''${bucketName}"
              '';
            };

            uid = mkOption {
              type = nullOr int;
              description = "User ID to own the mounted bucket.";
              default = null;
            };

            gid = mkOption {
              type = nullOr int;
              description = "Group ID to own the mounted bucket.";
              default = null;
            };

            umask = mkOption {
              type = int;
              default = 022;
              description = ''
                Umask for the mounted bucket.

                Files default to 666 and directories to 777, so a umask of 022 results
                in files being created with permissions 644 and directories with 755.

                See the umask bits table below for details:
                | Umask Bit | File Permissions | Directory Permissions |
                |-----------|------------------|-----------------------|
                | 0         | rw-              | rwx                   |
                | 1         | rw-              | rw-                   |
                | 2         | r--              | r-x                   |
                | 3         | r--              | r--                   |
                | 4         | -w-              | -wx                   |
                | 5         | -w-              | -w-                   |
                | 6         | ---              | -x-                   |
                | 7         | ---              | ---                   |

                A online calculator can be found at https://www.howtouselinux.com/linux-umask-calculator
              '';
            };
          };
        }
      )
    );
    default = { };
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
        nameValuePair "S3FS_AUTH/${toUpper name}" (
          lib.filterAttrs (_: v: v != null) {
            inherit (value) uid gid;
          }
        )
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
          ]
          ++ lib.optional (bucketCfg.uid != null) "uid=${toString bucketCfg.uid}"
          ++ lib.optional (bucketCfg.gid != null) "gid=${toString bucketCfg.gid}";
        }
      );
  };
}
