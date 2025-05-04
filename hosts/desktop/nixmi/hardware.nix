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
  ];

  hardware = {
    graphics.manufacturer = [
      "amd"
      "nvidia"
    ];

    nvidia.prime = {
      offload = {
        enable = true;
        enableOffloadCmd = true;
      };

      amdgpuBusId = "PCI:116:0:0";
      nvidiaBusId = "PCI:1:0:0";
    };

    storage = {
      enable = true;
      root = {
        enableLuks = true;
        devPath = "/dev/disk/by-id/nvme-KINGSTON_SKC3000D4096G_50026B7686F8E2BA";
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
        connector = "HDMI-A-2";
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
}
