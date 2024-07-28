{ inputs, modulesPath, ... }: {
  imports = [
    inputs.attic.nixosModules.atticd
    "${modulesPath}/virtualisation/proxmox-lxc.nix"
  ];

  sops.secrets = { };

  services = {
    uptime-kuma = {
      enable = true;
      settings = { };
    };

    netdata = {
      enable = true;
      config = {
        bind = "";
      };
    };
  };

  networking.firewall.allowedTCPPorts = [ ];
}
