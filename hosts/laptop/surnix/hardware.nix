{ inputs, ... }: {
  imports = [
    inputs.nixos-hardware.nixosModules.microsoft-surface-pro-intel
    inputs.nixos-hardware.nixosModules.common-hidpi
  ];

  boot = {
    initrd = {
      availableKernelModules = [ "xhci_pci" "nvme" "usb_storage" "sd_mod" ];
    };

    kernelModules = [ "kvm-intel" ];
  };

  host = {
    drive = {
      enable = true;

      format = "btrfs";
      name = "Nix";
    };

    persistence = {
      enable = true;
      type = "snapshot";

      directories = [
        "/var/lib/private/ollama"
      ];
    };
  };

  fileSystems = {
    "/boot" = {
      device = "/dev/disk/by-partlabel/ESP";
      fsType = "vfat";
    };
  };
}
