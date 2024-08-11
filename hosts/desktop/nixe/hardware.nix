# TODO :: Auto subvolume setup
{ inputs, pkgs, ... }: {
  imports = [
    inputs.nixos-hardware.nixosModules.common-cpu-amd
    inputs.nixos-hardware.nixosModules.common-cpu-amd-pstate
    inputs.nixos-hardware.nixosModules.common-pc-ssd
    inputs.nixos-hardware.nixosModules.common-hidpi
  ];

  hardware = {
    graphics.manufacturer = "nvidia";
    backlight.enable = false;
    cooling.enable = true;
    rgb.enable = true;

    # Disable motherboards really shit bluetooth module.
    bluetooth.disabledDevices = [
      {
        vendorId = "8087";
        productId = "0029";
      }
    ];
  };

  boot = rec {
    kernelPackages = pkgs.linuxPackages_zen;
    kernelModules = [ "v4l2loopback" ];
    extraModulePackages = [
      kernelPackages.v4l2loopback
      kernelPackages.universal-pidff
    ];

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
