{ config, lib, ... }:
let
  cfg = config.hardware.storage;
in
{
  imports = [
    ./ephemeral.nix
    ./luks.nix
    ./maintenance.nix
  ];

  options.hardware.storage = {
    enable = lib.mkEnableOption "storage management";

    root = lib.mkOption {
      default = { };
      type = lib.types.submodule {
        options = {
          enableLuks = lib.mkEnableOption "use LUKS encryption";

          label = lib.mkOption {
            type = lib.types.str;
            default = "root";
            description = ''
              The label of the root partition.
            '';
          };

          name = lib.mkOption {
            type = lib.types.str;
            default = config.networking.hostName;
            description = ''
              The name of the root device for usage within disko.
            '';
          };

          devPath = lib.mkOption {
            type = lib.types.str;
            description = ''
              The path to the device to use as the root device.
            '';
          };

          physicalSwap = lib.mkOption {
            default = { };
            type = lib.types.submodule {
              options = {
                enable = lib.mkEnableOption "physical swap";
                size = lib.mkOption {
                  type = lib.types.int;
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

    withImpermanence = lib.mkOption {
      type = lib.types.bool;
      readOnly = true;
      default =
        config.environment.persistence ? "/persist" && config.environment.persistence."/persist".enable;
    };
  };

  config = lib.mkIf cfg.enable {
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
  };
}
