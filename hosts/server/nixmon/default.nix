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

    caddy.enable = true;
    caddy.virtualHosts = {
      uptime.extraConfig = ''
        reverse_proxy http://localhost:3001
      '';
    };
  };

  networking.firewall.allowedTCPPorts = [ ];
}
