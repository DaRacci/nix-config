{
  self,
  modulesPath,
  config,
  lib,
  ...
}:
{
  imports = [
    "${modulesPath}/virtualisation/proxmox-lxc.nix"

    "${self}/modules/nixos/server"
    ./metrics.nix
  ];

  services = {
    getty.autologinUser = "root";
    resolved = {
      enable = true;
      extraConfig = ''
        MulticastDNS=yes
      '';
    };
  };

  proxmoxLXC = {
    manageNetwork = true;
    manageHostName = true;
  };
  networking = {
    domain = "localdomain";
    useHostResolvConf = false;
  };

  nix = {
    distributedBuilds = true;
    buildMachines = lib.mkIf (config.system.name != "nixserv") [
      {
        hostName = self.nixosConfigurations.nixserv.config.system.name;
        system = "x86_64-linux";
        protocol = "ssh-ng";
        sshUser = "builder";
        sshKey = config.sops.secrets.SSH_PRIVATE_KEY.path;
        supportedFeatures = [
          "kvm"
          "nixos-test"
          "big-parallel"
          "benchmark"
        ];
      }
    ];
  };
}
