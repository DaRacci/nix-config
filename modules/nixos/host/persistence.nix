{ config, lib, ... }: with lib; let cfg = config.host.persistence; in {
  options.host.persistence = {
    enable = mkEnableOption "Enable persistence for the host";

    root = mkOption {
      type = types.str;
      default = "/persist";
      description = ''
        The root directory for the host's persistent state.
      '';
    };

    type = mkOption {
      type = types.enum [ "tmpfs" "btrfs" "zfs" ];
      default = "tmpfs";
    };

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
    (optional cfg.persistence.enable flake.inputs.impermanence.nixosModules.impermanence)
  ];

  config = mkIf cfg.enable {
    environment.persistence."/persist" = {
      inherit (cfg.persistence) directories files;
    };

    fileSystems."/persist" = {
      device = "/dev/disk/by-partlabel/${hostName}";
      fsType = "btrfs";
      options = [ "subvol=@persist" "compress=zstd" ];
      neededForBoot = true;
    };

    services.btrfs = mkIf (cfg.type == "btrfs") {
      scrub = {
        enable = mkDefault true;
        fileSystems = [ "/persist" ];
        interval = "weekly";
      };
    };

    services.snapper.configs = mkIf (cfg.type == "btrfs") {
      persist = {
        SUBVOLUME = "/persist";
        TIMELINE_CREATE = true;
        TIMELINE_CLEANUP = true;
      };
    };
  };
}
