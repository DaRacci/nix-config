# TODO :: Auto subvolume setup
{ inputs, pkgs, ... }: {
  imports = [
    inputs.nixos-hardware.nixosModules.common-cpu-amd
    inputs.nixos-hardware.nixosModules.common-cpu-amd-pstate
    inputs.nixos-hardware.nixosModules.common-pc-ssd
    inputs.nixos-hardware.nixosModules.common-hidpi

    ../common/optional/nvidia.nix
    ../common/optional/backlight.nix
    ../common/optional/openrgb.nix
  ];

  boot = {
    kernelPackages = pkgs.unstable.linuxPackages_6_5;

    initrd = {
      # TODO :: Needed? ahci, sd_mod usbhid usb_storage
      availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usb_storage" "usbhid" "sd_mod" ];
    };

    loader = {
      efi.canTouchEfiVariables = true;
      systemd-boot = {
        enable = true;
        consoleMode = "max"; # TODO : Whats this do?
      };

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

    "/persist" = {
      device = "/dev/disk/by-partlabel/Nix";
      fsType = "btrfs";
      options = [ "subvol=@persist" ];
      neededForBoot = true;
    };

    "/nix" = {
      device = "dev/disk/by-partlabel/Nix";
      fsType = "btrfs";
      options = [ "subvol=@store" ];
      neededForBoot = true;
    };

    "/mnt/mega" = {
      device = "/dev/disk/by-partlabel/mega-hdd";
      fsType = "btrfs";
      options = [ "nofail" ];
    };

    "/mnt/btrfs-pool" = {
      device = "/dev/disk/by-label/btrfs-pool";
      fsType = "btrfs";
      options = [ "nofail" ];
    };
  };

  hardware = {
    #? TODO :: Globalise
    # keyboard.qmk.enable = true;

    #? TODO :: Globalise
    bluetooth.enable = true;
  };
}
