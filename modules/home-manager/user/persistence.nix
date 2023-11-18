{ flake, host, config, lib, ... }: with lib; let cfg = config.user.persistence; in {
  options.system.persistence = {
    enable = mkEnableOption "persistence" host.persistence.enable;

    directories = mkOption {
      type = with types; listOf (either str (submodule {
        options = {
          directory = mkOption {
            type = str;
            default = null;
          };
          method = mkOption {
            type = types.enum [ "bindfs" "symlink" ];
            default = "bindfs";
          };
        };
      }));
      default = [ ];
    };

    files = mkOption {
      type = with types; listOf str;
      default = [ ];
    };
  };

  imports = [
    (optional cfg.persistence.enable flake.inputs.impermanence.nixosModules.home-manager.impermanence)
  ];

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = !host.persistence.enable;
        message = ''
          The "persistence" option is enabled, but the host does not have
          persistence enabled. This is probably a mistake, user persistence cannot be
          enabled without host persistence.
        '';
      }
    ];

    home.persistence = mkIf cfg.enable {
      "${host.persistence.root}/home/${config.home.username}" = {
        inherit (cfg.persistence) files;

        directories = [
          "Documents"
          "Downloads"
          "Pictures"
          "Videos"
          "Music"
          "Templates"
          ".local/share/keyrings"
        ] ++ cfg.persistence.directories;

        allowOther = true;
      };
    };
  };
}
