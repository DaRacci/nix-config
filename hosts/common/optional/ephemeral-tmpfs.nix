{ config, ... }:
let inherit (config.networking) hostName; in {
  imports = [ ./btrfs.nix ./persistence.nix ];

  fileSystems = {
    "/" = {
      device = "none";
      fsType = "tmpfs";
      options = [ "defaults" "size=16G" "mode=755" ];
    };

    "/nix" = {
      device = "/dev/disk/by-partlabel/${hostName}";
      fsType = "btrfs";
      options = [ "subvol=@nix" "noatime" "compress=zstd" ];
      neededForBoot = true;
    };

    "/persist" = {
      device = "/dev/disk/by-partlabel/${hostName}";
      fsType = "btrfs";
      options = [ "subvol=@persist" "compress=zstd" ];
      neededForBoot = true;
    };
  };
}