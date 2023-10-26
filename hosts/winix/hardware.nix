{ inputs, pkgs, ... }: {
  imports = [
    inputs.nixos-hardware.nixosModules.common-cpu-amd
    inputs.nixos-hardware.nixosModules.common-cpu-amd-pstate
    inputs.nixos-hardware.nixosModules.common-pc-ssd
  ];

  fileSystems = {
    "/" = {
      device = "none";
      fsType = "tmpfs";
      options = [ "defaults" "size=8G" "mode=755" ];
    };

    "/persist" = {
      device = "/dev/disk/by-partlabel/Nix";
      fsType = "btrfs";
      options = [ "subvol=@persist-winix" ];
      neededForBoot = true;
    };

    "/nix" = {
      device = "/dev/disk/by-partlabel/Nix";
      fsType = "btrfs";
      options = [ "subvol=@store" "noatime" ];
      neededForBoot = true;
    };
  };
}
