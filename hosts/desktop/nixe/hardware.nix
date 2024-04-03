# TODO :: Auto subvolume setup
{ flake, inputs, pkgs, ... }: {
  imports = [
    inputs.nixos-hardware.nixosModules.common-cpu-amd
    inputs.nixos-hardware.nixosModules.common-cpu-amd-pstate
    inputs.nixos-hardware.nixosModules.common-pc-ssd
    inputs.nixos-hardware.nixosModules.common-hidpi

    "${flake}/hosts/shared/optional/nvidia.nix"
    "${flake}/hosts/shared/optional/backlight.nix"
    "${flake}/hosts/shared/optional/openrgb.nix"
    "${flake}/hosts/shared/optional/cooling.nix"
    "${flake}/hosts/shared/optional/secureboot.nix"
    "${flake}/hosts/shared/optional/biometrics.nix"
  ];

  boot = {
    kernelPackages = pkgs.linuxPackages_zen;

    initrd = {
      # TODO :: Needed? ahci, sd_mod usbhid usb_storage
      availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usb_storage" "usbhid" "sd_mod" ];
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
