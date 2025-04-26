{ config, ... }:
{
  sops.secrets = {
    GITHUB_TOKEN = {
      owner = config.users.users.runner.name;
      group = config.users.groups.runner.name;
    };
  };

  users = {
    users.runner = {
      name = "runner";
      group = "runner";
      isSystemUser = true;
    };

    groups.runner = {
      name = "runner";
    };
  };

  services = rec {
    coder = {
      enable = true;
      accessUrl = "https://coder.racci.dev";
      listenAddress = "0.0.0.0:8080";
    };

    github-runners = {
      runner = {
        enable = true;
        user = null;
        group = null;
        url = "https://github.com/DaRacci/nix-config";
        tokenFile = config.sops.secrets.GITHUB_TOKEN.path;
      };
    };

    caddy.virtualHosts.coder.extraConfig = ''
      reverse_proxy http://${coder.listenAddress}
    '';
  };

  users.extraUsers.coder = {
    extraGroups = [ "docker" ];
  };

  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
  };

  networking.firewall = {
    allowedTCPPorts = [ 8080 ];
  };
}
