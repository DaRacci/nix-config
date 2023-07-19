{ inputs, ... }: {
  imports = [
    inputs.nixos-hardware.nixosModules.microsoft-surface-pro-intel
    inputs.nixos-hardware.nixosModules.common-hidpi
  ];

  boot = {
    initrd = {
      availableKernelModules = [ "xhci_pci" "nvme" "usb_storage" "sd_mod" ];
      kernelModules = [ ];
    };

    kernelModules = [ "kvm-intel" ];
    extraModulePackages = [ ];
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-uuid/88fc3edb-0750-40de-9f8e-db6891d1a3db";
      fsType = "btrfs";
    };

    "/boot" = {
      device = "/dev/disk/by-uuid/E0E0-ED76";
      fsType = "vfat";
    };
  };
}
