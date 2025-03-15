{
  flake,
  inputs,
  pkgs,
  ...
}:
{
  imports = [
    inputs.nixos-hardware.nixosModules.common-cpu-amd
    inputs.nixos-hardware.nixosModules.common-cpu-amd-pstate
    inputs.nixos-hardware.nixosModules.common-pc-ssd
    inputs.nixos-hardware.nixosModules.common-hidpi

    "${flake}/hosts/shared/disks/btrfs-luks-disk.nix"
  ];

  hardware = {
    graphics.manufacturer = "nvidia";
    backlight.enable = true;
    cooling.enable = true;
  };

  boot = rec {
    kernelPackages = pkgs.linuxPackages_xanmod_latest;
    kernelModules = [ "v4l2loopback" ];
    extraModulePackages = [
      kernelPackages.v4l2loopback
      kernelPackages.universal-pidff
    ];

    initrd = {
      availableKernelModules = [
        "nvme"
        "xhci_pci"
        "ahci"
        "usb_storage"
        "usbhid"
        "sd_mod"
      ];
    };

    loader = {
      efi.canTouchEfiVariables = true;

      #? TODO :: Globalise
      #? TODO :: Custom Windows Entry
      grub = {
        efiSupport = true;

        # TODO :: Better theme
        theme = pkgs.nixos-grub2-theme;
        memtest86.enable = true;
      };
    };
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-partlabel/ESP";
    fsType = "vfat";
  };
}
