{ config, lib, ... }:
let
  cfg = config.hardware.storage;
in
{
  options.hardware.storage.maintenance = {
    enable = lib.mkEnableOption "storage device maintenance";
  };

  config = lib.mkIf cfg.maintenance.enable {
    services.btrfs.autoScrub = {
      enable = true;
      fileSystems =
        builtins.attrNames
          config.disko.devices.disk.${cfg.root.name}.content.partitions.root.content.subvolumes;
      interval = "Wed *-*-* 02:00:00";
    };
  };
}
