{ config, lib, ... }:
let
  cfg = config.hardware.storage;
in
{
  options.hardware.storage.luks = {
    enable = lib.mkEnableOption "usage of LUKS encrypted storage";
  };

  config = lib.mkIf cfg.luks.enable {
    disko.devices.disk.${cfg.root.name}.content.partitions.luks = {

    };
  };
}
