# TODO :: Auto subvolume setup
{ config, lib, inputs, pkgs, ... }: {
  imports = [
    inputs.nixos-hardware.nixosModules.common-cpu-amd
    inputs.nixos-hardware.nixosModules.common-cpu-amd-pstate
    inputs.nixos-hardware.nixosModules.common-pc-ssd
    inputs.nixos-hardware.nixosModules.common-hidpi

    ../common/optional/impermanence.nix
    ../common/optional/nvidia.nix
    ../common/optional/virtualisation.nix
    ../common/optional/fan2go.nix
  ];

  boot = {
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
  };

  zramSwap = {
    enable = true;
    priority = 5;
    algorithm = "zstd";
    memoryMax = null;
    memoryPercent = 50;
  };

  # TODO :: Disk swap
  swapDevices = [];

  hardware = {
    #? TODO :: Globalise
    keyboard.qmk.enable = true;

    #? TODO :: Globalise
    bluetooth.enable = true;
  };

  services = {
    hardware.openrgb = {
      enable = true;
      motherboard = "amd";
      package = pkgs.openrgb-with-all-plugins;
    };
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
