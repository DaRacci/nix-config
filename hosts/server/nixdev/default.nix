{ config, modulesPath, ... }: {
  imports = [
    "${modulesPath}/virtualisation/proxmox-lxc.nix"
  ];

  services = {
    coder = {
      enable = true;
      accessUrl = "https://coder.racci.dev";
    };

    caddy = {
      enable = true;
      email = "admin@racci.dev";

      virtualHosts = {
        "coder.racci.dev" = {
          extraConfig = ''
            reverse_proxy {
              to http://${config.services.coder.listenAddress}
            }
          '';
        };
      };
    };
  };

  networking.firewall = {
    allowedTCPPorts = [ 80 443 ];
  };
}
