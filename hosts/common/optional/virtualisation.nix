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

  environment = {
    sessionVariables.LIBVIRT_DEFAULT_URI = [ "qemu:///system" ];
    systemPackages = with pkgs; [
      virt-manager
      virtiofsd
      looking-glass-client
      win-virtio win-spice win-qemu
    ];

    persistence."/persist" = {
      directories = [
        { directory = "/var/lib/libvirt/qemu"; user = "qemu-libvirtd"; group = "qemu-libvirtd"; mode = "u=rwx,g=rx,o=rx"; }
      ];
    };
  };
}
