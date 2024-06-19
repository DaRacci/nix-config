{ config, pkgs, modulesPath, ... }: {
  imports = [
    "${modulesPath}/virtualisation/proxmox-lxc.nix"
  ];

  sops.secrets = {
    # CLOUDFLARE_API_TOKEN = { };
    HARMONIA_SECRET = { };
  };

  services = rec {
    harmonia = {
      enable = true;
      package = pkgs.harmonia;
      signKeyPath = config.sops.secrets.HARMONIA_SECRET.path;
      settings = {
        bind = "127.0.0.1:5000";
        workers = 4;
        max_connection_rate = 256;
        priority = 50;
      };
    };

    # caddy = {
    #   enable = true;

    #   virtualHosts."cache.racci.dev".extraConfig = ''
    #     encode {
    #       zstd
    #       match {
    #         header Content-Type application/x-nix-archive
    #       }
    #     }

    #     reverse_proxy {
    #       to http://${harmonia.settings.bind}
    #     }
    #   '';
    # };
  };

  networking.firewall.allowedTCPPorts = [ 5000 ];
}
