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
    "${modulesPath}/profiles/headless.nix"
    "${self}/modules/nixos/server"

    ./reduce.nix
  ];

  services = {
    getty.autologinUser = "root";

    metrics = {
      enable = true;
      upgradeStatus = {
        enable = true;
        uptimeKuma.enable = true;
      };
      hacompanion = {
        enable = true;
        sensor = {
          cpu_usage.enable = true;
          uptime.enable = true;
          memory.enable = true;
          load_avg.enable = true;
        };
      };
    };
  };

  proxmoxLXC = {
    manageNetwork = true;
    manageHostName = true;
  };
  networking = {
    domain = "localdomain";
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
