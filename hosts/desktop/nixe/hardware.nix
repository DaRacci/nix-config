{
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

    storage = {
      enable = false;
      root = {
        label = "Nix";
        devPath = "/dev/disk/by-id/nvme-KINGSTON_SKC3000D2048G_50026B76857EB93E";
        ephemeral = {
          enable = true;
          type = "tmpfs";
          tmpfsSize = 16;
        };
      };
    };

    display = {
      virtual = {
        enable = true;
        resolution = "2048x2732";
        refreshRate = 120;
        edidBinary = ./ipad-pro-edid.bin;
        connector = "HDMI-A-1";
      };
    };
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

  fileSystems = {
    "/boot" = {
      device = "/dev/disk/by-partlabel/ESP";
      fsType = "vfat";
    };

    "/nix" = {
      device = "/dev/disk/by-partlabel/Nix";
      fsType = "btrfs";
      options = [
        "subvol=@store"
        "noatime"
        "compress=zstd"
      ];
      neededForBoot = true;
    };

    "/persist" = {
      device = "/dev/disk/by-partlabel/Nix";
      fsType = "btrfs";
      options = [
        "subvol=@persist"
        "compress=zstd"
      ];
      neededForBoot = true;
    };

    "/" = {
      device = "none";
      fsType = "tmpfs";
      options = [
        "defaults"
        "size=16G"
        "mode=755"
      ];
      neededForBoot = false;
    };
  };
}
