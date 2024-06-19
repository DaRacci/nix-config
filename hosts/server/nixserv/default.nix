{ inputs, config, pkgs, modulesPath, ... }: {
  imports = [
    inputs.attic.nixosModules.atticd
    "${modulesPath}/virtualisation/proxmox-lxc.nix"
  ];

  sops.secrets = {
    ATTIC_SECRET = { };
    HARMONIA_SECRET = { };
  };

  services = {
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

    atticd = {
      enable = true;
      credentialsFile = config.sops.secrets.ATTIC_SECRET.path;
      settings = {
        listen = "127.0.0.1:8080";

        chunking = {
          nar-size-threshold = 64 * 1024;
          min-size = 16 * 1024;
          avg-size = 64 * 1024;
          max-size = 256 * 1024;
        };
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

  networking.firewall.allowedTCPPorts = [ 5000 8080 ];
}
