{ inputs, config, lib, ... }: with lib; {
  imports = [
    inputs.attic.nixosModules.atticd
  ];

  sops.secrets = trivial.pipe [
    "ATTIC_SECRET"
    "CLOUDFLARE_API_TOKEN"
  ] [
    # Create a blank attr for each secret
    (map (secret: nameValuePair secret { }))
    attrsToList
  ];

  services.atticd = {
    enable = true;
    credentialsFile = ""; # From sops?

    settings = {
      listen = "[::]:8080";

      chunking = {
        nar-size-threshold = 64 * 1024;
        min-size = 16 * 1024;
        avg-size = 64 * 1024;
        max-size = 256 * 1024;
      };
    };
  };

  # services.nginx = {
  #   enable = true;
  #   recommendedProxySettings = true;
  #   virtualHosts = {
  #     # ... existing hosts config etc. ...
  #     "binarycache.example.com" = {
  #       locations."/".proxyPass = "http://${config.services.nix-serve.bindAddress}:${toString config.services.nix-serve.port}";
  #     };
  #   };
  # };

  services.caddy = {
    enable = true;
    email = "admin@racci.dev";

    virtualHosts = {
      "nix.racci.dev" = {
        extraConfig = ''
          reverse_proxy 127.0.0.1:8080
        '';
      };
    };
  };
}
