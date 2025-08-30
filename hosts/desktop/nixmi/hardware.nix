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
    cooling.enable = false;

    graphics = {
      reduceMesa = false;

      manufacturer = [
        "amd"
        "nvidia"
      ];
    };

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
        enable = false;
        resolution = "2048x2732";
        refreshRate = 120;
        edidBinary = ./ipad-pro-edid.bin;
        connector = "HDMI-A-2";
      };
    };
  };

  boot = rec {
    kernelPackages = pkgs.linuxKernel.packages.linux_zen;
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

      grub = {
        efiSupport = true;
        memtest86.enable = true;
      };
    };
  };
}
