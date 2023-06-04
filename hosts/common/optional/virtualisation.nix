{ pkgs, config, nur, ... }:

let
  nur-no-pkgs = import (builtins.fetchTarball "https://github.com/nix-community/NUR/archive/master.tar.gz") {};
  bridgeInterface = "br0";
  ethInterface = "eth0";
in {
  imports = [
    nur-no-pkgs.repos.crtified.modules.vfio
    nur-no-pkgs.repos.crtified.modules.virtualisation.nix
  ];

  # boot = {
  #   boot.kernelModules = [ "vfio_pci" "vfio_iommu_type1" "vfio" ];
  #   kernelParams = [ "amd_iommu=on" ];

  #   # TODO :: Globalise
  #   extraModprobeConfig = "options vfio_pci ids=10de:1b06,10de:10ef";
  # };

	virtualisation = {
    vfio = {
      enable = true;
      IOMMUType = "amd";
      devices = [ "10de:1b06" "10de:10ef" ];
    };

    sharedMemoryFiles = {
      looking-glass = {
        user = "racci";
        group = "qemu-libvirtd";
        mode = "666";
      };
    };

    libvirtd = {
      enable = true;
      onBoot = "ignore";
      onShutdown = "shutdown";

      allowedBridges = [ "${bridgeInterface}" ];

      qemu = {
        runAsRoot = false;
        ovmf.enable = true;
      };

      # deviceACL = [
      #   "/dev/vfio/vfio"
      #   "/dev/kvm"
      #   "/dev/shm/looking-glass"
      # ];
    };
	};

  networking = {
    interfaces."${bridgeInterface}".useDHCP = true;
    bridges."${bridgeInterface}".interfaces = [ "${ethInterface}" ];
  };

  # Creates the required IVSHMEM file for looking-glass.
  # systemd.tmpfiles.rules = [
  #   "f /dev/shm/looking-glass 0660 user kvm -"
  # ];

  environment = {
    sessionVariables.LIBVIRT_DEFAULT_URI = [ "qemu:///system" ];
    systemPackages = with pkgs; [
      virt-manager
      looking-glass-client
      win-virtio win-spice win-qemu
    ];

    persistence."/persist" = {
      directories = [
        { directory = "/etc/libvirt/qemu"; user = "qemu-libvirtd"; group = "qemu-libvirtd"; mode = "u=rwx,g=rx,o="; }
      ];
    };
  };
}
