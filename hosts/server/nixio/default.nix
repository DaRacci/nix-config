{ config, modulesPath, pkgs, ... }: {
  imports = [
    "${modulesPath}/virtualisation/proxmox-lxc.nix"
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

  networking.firewall = {
    allowedTCPPorts = [ 80 443 ];
  };

  services.caddy = {
    enable = true;
    email = "admin@racci.dev";

    virtualHosts = {
      "minio.racci.dev" = {
        extraConfig = ''
          redir /console /console/

          handle_path /console/* {
            reverse_proxy {
              to ${config.services.minio.consoleAddress}
            }
          }

          reverse_proxy {
            to ${config.services.minio.listenAddress}
          }
        '';
      };
    };
  };
}
