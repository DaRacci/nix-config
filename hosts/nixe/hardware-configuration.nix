{ lib, inputs, pkgs }: {
  imports = [
    # ../common/optional/ephemeral-btrfs.nix
    # ../common/optional/encrypted-root.nix
    inputs.nixos-hardware.nixosModules.common-cpu-amd
    inputs.nixos-hardware.nixosModules.common-cpu-amd-pstate
    inputs.nixos-hardware.nixosModules.common-gpu-nvidia
    inputs.nixos-hardware.nixosModules.common-pc-ssd
    inputs.nixos-hardware.nixosModules.common-hidpi
  ];

  boot = {
    initrd = {
      # TODO :: Needed? ahci, sd_mod usbhid usb_storage
      availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usb_storage" "usbhid" "sd_mod" ];
      kernelModules = [ "kvm-amd" ]; # TODO :: Move to virtualisation common?
    };

    loader = {
      efi.canTouchEfiVariables = true;
      systemd-boot = {
        enable = true;
        consoleMode = "max"; # TODO : Whats this do?
      };
      grub = {
        default = "saved";
        useOsProber = true;
        device = "nodev"; # TODO : Disable when ready for bootloader install
      };
    };
  };

  fileSystems = {
    "/" = {
      device = "none";
      fsType = "tmpfs";
      options = [ "size=16GB" "mode=755" ];
    };

    "/boot" = {
      device = "/dev/disk/by-label/ESP";
      fsType = "vfat";
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
    nvidia = {
      modesetting.enable = true;
      nvidiaPersistenced = true;
      powerManagement.enable = true;
      open = false; #? TODO :: Change once it works fully
    };

    #? TODO :: Globalise
    keyboard.qmk.enable = true;

    #? TODO :: Globalise
    bluetooth.enable = true;
  };

  services.hardware.openrgb = {
    enable = true;
    motherboard = "amd";
    package = pkgs.openrgb-with-all-plugins;
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
