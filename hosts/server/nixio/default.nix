{ flake, config, modulesPath, pkgs, ... }: {
  imports = [
    "${modulesPath}/virtualisation/proxmox-lxc.nix"
    "${flake}/hosts/shared/optional/tailscale.nix"
  ];

  sops.secrets = {
    MINIO_ROOT_CREDENTIALS = { };
  };

  services = {
    minio = {
      enable = true;
      package = pkgs.minio;
      rootCredentialsFile = config.sops.secrets.MINIO_ROOT_CREDENTIALS.path;
    };
  };

  systemd.services.minio = {
    serviceConfig = {
      environment = {
        MINIO_BROWSER_REDIRECT_URL = "http://minio.racci.dev/console";
      };
    };
  };

  networking.firewall = {
    allowedTCPPorts = [ 9000 9001 ];
  };

  # services.caddy = {
  #   enable = true;
  #   email = "admin@racci.dev";

  #   virtualHosts = {
  #     "minio.racci.dev" = {
  #       extraConfig = ''
  #         redir /console /console/

  #         handle_path /console/* {
  #           reverse_proxy {
  #             to ${config.services.minio.consoleAddress}
  #           }
  #         }

  #         reverse_proxy {
  #           to ${config.services.minio.listenAddress}
  #         }
  #       '';
  #     };
  #   };
  # };
}
