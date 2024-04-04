{ flake, osConfig, config, lib, ... }: with lib;
let
  cfg = config.user.persistence;
in
{
  options.user.persistence = {
    enable = mkEnableOption "persistence";

    directories = mkOption {
      type = with types; listOf (either str (submodule {
        options = {
          directory = mkOption {
            type = str;
            default = null;
            description = "The directory path to be linked.";
          };
          method = mkOption {
            type = types.enum [ "bindfs" "symlink" ];
            default = "bindfs";
            description = ''
              The linking method that should be used for this
              directory. bindfs is the default and works for most use
              cases, however some programs may behave better with
              symlinks.
            '';
          };
        };
      }));
      default = [ ];
      example = [
        "Downloads"
        "Music"
        "Pictures"
        "Documents"
        "Videos"
        "VirtualBox VMs"
        ".gnupg"
        ".ssh"
        ".local/share/keyrings"
        ".local/share/direnv"
        {
          directory = ".local/share/Steam";
          method = "symlink";
        }
      ];
      description = ''
        A list of directories in your home directory that
        you want to link to persistent storage. You may optionally
        specify the linking method each directory should use.
      '';
    };

    files = mkOption {
      type = with types; listOf str;
      default = [ ];
      example = [
        ".screenrc"
      ];
      description = ''
        A list of files in your home directory you want to
        link to persistent storage.
      '';
    };

    removePrefixDirectory = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = ''
        Note: This is mainly useful if you have a dotfiles
        repo structured for use with GNU Stow; if you don't,
        you can likely ignore it.

        Whether to remove the first directory when linking
        or mounting; e.g. for the path
        <literal>"screen/.screenrc"</literal>, the
        <literal>screen/</literal> is ignored for the path
        linked to in your home directory.
      '';
    };
  };

  imports = [ flake.inputs.impermanence.nixosModules.home-manager.impermanence ];

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = osConfig.host.persistence.enable;
        message = ''
          The "persistence" option is enabled, but the host does not have
          persistence enabled. This is probably a mistake, user persistence cannot be
          enabled without host persistence.
        '';
      }
    ];

    home.persistence = mkIf cfg.enable {
      "${osConfig.host.persistence.root}/home/${config.home.username}" = {
        inherit (cfg) files;

        directories = [
          "Documents"
          "Downloads"
          "Pictures"
          "Videos"
          "Music"
          "Templates"
          ".local/share/keyrings"
        ] ++ cfg.directories;

        allowOther = true;
      };
    };
  };
}
