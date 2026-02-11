{ config, lib, ... }:
let
  inherit (lib)
    mkIf
    mkMerge
    mkOption
    mkEnableOption
    ;
  inherit (lib.types)
    submodule
    str
    int
    bool
    ;

  cfg = config.hardware.storage;
in
{
  imports = [
    ./ephemeral.nix
    ./maintenance.nix
  ];

  options.hardware.storage = {
    enable = mkEnableOption "storage management";

    root = mkOption {
      default = { };
      type = submodule {
        options = {
          enableLuks = mkEnableOption "use LUKS encryption";

          label = mkOption {
            type = str;
            default = "root";
            description = ''
              The label of the root partition.
            '';
          };

          name = mkOption {
            type = str;
            description = ''
              The name of the root device for usage within disko.
            '';
          };

          devPath = mkOption {
            type = str;
            description = ''
              The path to the device to use as the root device.
            '';
          };

          physicalSwap = mkOption {
            default = { };
            type = submodule {
              options = {
                enable = mkEnableOption "physical swap";
                size = mkOption {
                  type = int;
                  default = 2;
                  description = ''
                    The size of the swap partition in GiB.
                  '';
                };
              };
            };
          };
        };
      };
    };

    withImpermanence = mkOption {
      type = bool;
    };
  };

  config = mkMerge [
    {
      hardware.storage = {
        root.name = config.networking.hostName;

        withImpermanence = config.environment.persistence ? "/persist" && config.environment.persistence."/persist".enable;
      };
    }

    (mkIf cfg.enable {
      disko.devices = {
        disk."${cfg.root.name}" = {
          type = "disk";
          device = cfg.root.devPath;
          content = {
            type = "gpt";
            partitions = {
              ESP = import ./partitions/esp.nix;

              root = lib.mkIf (!cfg.root.enableLuks) {
                size = "100%";
                inherit (cfg.root) label;
                content = import ./partitions/btrfs.nix { inherit config lib; };
              };

              luks = lib.mkIf cfg.root.enableLuks {
                size = "100%";
                inherit (cfg.root) label;
                content = import ./partitions/luks.nix { inherit config lib; };
              };
            };
          };
        };
      };

      fileSystems = {
        "/persist" = lib.mkIf cfg.withImpermanence { neededForBoot = true; };
        "/nix".neededForBoot = true;
      };
    })
  ];
}
