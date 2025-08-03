{
  self,
  config,
  lib,
  ...
}:
with lib;
with types;
let
  cfg = config.host.persistence;

  defaultPerms = {
    mode = "0755";
    user = "root";
    group = "root";
  };

  commonOpts = {
    options = {
      persistentStoragePath = mkOption {
        type = path;
        default = cfg.root;
        defaultText = "environment.persistence.‹name›.persistentStoragePath";
        description = ''
          The path to persistent storage where the real
          file or directory should be stored.
        '';
      };
      home = mkOption {
        type = nullOr path;
        default = null;
        internal = true;
        description = ''
          The path to the home directory the file is
          placed within.
        '';
      };
    };
  };

  dirPermsOpts = {
    user = mkOption {
      type = str;
      description = ''
        If the directory doesn't exist in persistent
        storage it will be created and owned by the user
        specified by this option.
      '';
    };
    group = mkOption {
      type = str;
      description = ''
        If the directory doesn't exist in persistent
        storage it will be created and owned by the
        group specified by this option.
      '';
    };
    mode = mkOption {
      type = str;
      example = "0700";
      description = ''
        If the directory doesn't exist in persistent
        storage it will be created with the mode
        specified by this option.
      '';
    };
  };

  fileOpts = {
    options = {
      file = mkOption {
        type = str;
        description = ''
          The path to the file.
        '';
      };
      parentDirectory =
        commonOpts.options
        // mapAttrs (
          _: x: if x._type or null == "option" then x // { internal = true; } else x
        ) dirOpts.options;
      filePath = mkOption {
        type = path;
        internal = true;
      };
    };
  };

  dirOpts = {
    options = {
      directory = mkOption {
        type = str;
        description = ''
          The path to the directory.
        '';
      };
      hideMount = mkOption {
        type = bool;
        default = true;
        defaultText = "environment.persistence.‹name›.hideMounts";
        example = true;
        description = ''
          Whether to hide bind mounts from showing up as
          mounted drives.
        '';
      };
      # Save the default permissions at the level the
      # directory resides. This used when creating its
      # parent directories, giving them reasonable
      # default permissions unaffected by the
      # directory's own.
      defaultPerms = mapAttrs (_: x: x // { internal = true; }) dirPermsOpts;
      dirPath = mkOption {
        type = path;
        internal = true;
      };
    }
    // dirPermsOpts;
  };

  rootFile = submodule [
    commonOpts
    fileOpts
    (
      { config, ... }:
      {
        parentDirectory = mkDefault (
          defaultPerms
          // rec {
            directory = dirOf config.file;
            dirPath = directory;
            inherit (config) persistentStoragePath;
            inherit defaultPerms;
          }
        );
        filePath = mkDefault config.file;
      }
    )
  ];

  rootDir = submodule (
    [
      commonOpts
      dirOpts
      (
        { config, ... }:
        {
          defaultPerms = mkDefault defaultPerms;
          dirPath = mkDefault config.directory;
        }
      )
    ]
    ++ (mapAttrsToList (n: v: { ${n} = mkDefault v; }) defaultPerms)
  );
in
{
  options.host.persistence = {
    enable = mkEnableOption "Enable persistence for the host";

    root = mkOption {
      type = str;
      default = "/persist";
      readOnly = true;
      description = ''
        The root directory for the host's persistent state.
      '';
    };

    files = mkOption {
      type = listOf (coercedTo str (f: { file = f; }) rootFile);
      default = [ ];
      example = [
        "/etc/machine-id"
        "/etc/nix/id_rsa"
      ];
      description = ''
        Files that should be stored in persistent storage.
      '';
    };

    directories = mkOption {
      type = listOf (coercedTo str (d: { directory = d; }) rootDir);
      default = [ ];
      example = [
        "/var/log"
        "/var/lib/nixos"
        "/var/lib/systemd/coredump"
        "/etc/NetworkManager/system-connections"
      ];
      description = ''
        Directories to bind mount to persistent storage.
      '';
    };
  };

  imports = [ self.inputs.impermanence.nixosModules.impermanence ];

  config = mkIf cfg.enable {
    programs.fuse.userAllowOther = true;

    system.activationScripts.persistent-dirs.text =
      let
        mkHomePersist =
          user:
          optionalString user.createHome ''
            mkdir -p /persist/${user.home}
            chown ${user.name}:${user.group} /persist/${user.home}
            chmod ${user.homeMode} /persist/${user.home}
          '';
        users = builtins.attrValues config.users.users;
      in
      concatLines (map mkHomePersist users);

    environment.persistence."/persist" = {
      hideMounts = true;

      directories = [
        "/var/lib/systemd"
        "/var/lib/nixos"
        "/var/log"
        "/etc/NetworkManager/system-connections"
      ]
      ++ cfg.directories;

      files = [
        "/etc/machine-id"
        {
          file = "/etc/nix/id_rsa";
          parentDirectory = {
            mode = "u=rwx,g=rx,o=rx";
          };
        }
      ]
      ++ cfg.files;

      users = lib.pipe (attrNames config.home-manager.users) [
        (filter (user: config.home-manager.users.${user}.user.persistence.enable))
        (map (
          user:
          nameValuePair user {
            inherit (config.home-manager.users.${user}.user.persistence) files directories;
          }
        ))
        lib.listToAttrs
      ];
    };

    # services.snapper.configs = mkIf (drive.format == "btrfs") (builtins.foldl' recursiveUpdate { }
    #   ([{
    #     persist = {
    #       SUBVOLUME = "/persist";
    #       TIMELINE_CREATE = true;
    #       TIMELINE_CLEANUP = true;
    #     };
    #   }] ++ builtins.map
    #     (user: {
    #       "${user.name}Home" = {
    #         SUBVOLUME = "${cfg.root}/home/${user.name}";
    #         TIMELINE_CREATE = true;
    #         TIMELINE_CLEANUP = true;
    #       };
    #     })
    #     (builtins.filter (user: user.createHome) (builtins.attrValues config.users.users))));
  };
}
