# This file contains an ephemeral btrfs root configuration
# TODO: perhaps partition using disko in the future
{ config, lib, ... }: with lib; let
  cfg = config.host.drive;
in
{
  options.host.drive = {
    enable = mkEnableOption "drive";

    name = mkOption {
      type = types.str;
      default = config.networking.hostName;
    };

    format = mkOption {
      type = types.enum [ "btrfs" ];
    };
  };

  config = mkIf cfg.enable {
    fileSystems."/nix" = mkIf (cfg.format == "btrfs") {
      device = "/dev/disk/by-partlabel/${cfg.name}";
      fsType = cfg.format;
      options = [ "subvol=@store" "noatime" "compress=zstd" ];
      neededForBoot = true;
    };
  };
}
