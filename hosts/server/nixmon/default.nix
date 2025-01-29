{ modulesPath, ... }:
{
  imports = [ "${modulesPath}/virtualisation/proxmox-lxc.nix" ];

  sops.secrets = { };

  services = {
    uptime-kuma = {
      enable = true;
      settings = {
        HOST = "::";
      };
    };

    # netdata = {
    #   enable = true;
    #   config = {
    #     bind = "";
    #   };
    # };

    caddy.virtualHosts = {
      uptime.extraConfig = ''
        reverse_proxy http://localhost:3001
      '';
    };
  };

  networking.firewall.allowedTCPPorts = [ 3001 ];
}
