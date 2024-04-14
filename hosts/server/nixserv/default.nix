{ inputs, config, modulesPath, ... }: {
  imports = [
    inputs.attic.nixosModules.atticd
    "${modulesPath}/virtualisation/proxmox-lxc.nix"
  ];

  sops.secrets = {
    ATTIC_SECRET = { };
    CLOUDFLARE_API_TOKEN = { };
  };

  services.atticd = {
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

  services.caddy = {
    enable = true;
    email = "admin@racci.dev";

    virtualHosts = {
      "nix.racci.dev" = {
        extraConfig = ''
          reverse_proxy ${config.services.atticd.settings.listen}
        '';
      };
    };
  };
}
