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

  fileSystems =
    let
      bootPart = "/dev/disk/by-partlabel/ESP";
    in
    {
      "/boot" = {
        device = bootPart;
        fsType = "vfat";
      };
    };
}
