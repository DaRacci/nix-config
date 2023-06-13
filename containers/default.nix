{ config, lib, pkgs, inputs, ... }: {
  imports = [ inputs.arion.nixosModules.arion ];

  environment.systemPackages = with pkgs; [
    podman-tui
    docker-client
  ];

  virtualisation = {
    docker.enable = false; # Just in case // All my homies hate docker // Podman is better
    oci-containers.backend = "podman";

    podman = {
      enable = true;
      package = pkgs.podman;
      extraPackages = with pkgs; [ ];

      defaultNetwork.settings.dns_name = true;

      dockerCompat = true;
      dockerSocket.enable = true;

      # TODO: Check for nvidia gpu
      enableNvidia = true;

      networkSocket = {
        enable = false; # TODO?
        listenAddress = "0.0.0.0";
      };

      autoPrune = {
        enable = true;
        dates = "weekly";
        flags = [ ];
      };
    };
  };

  virtualisation.arion = {
    backend = "podman-socket";
    projects = {
      global.settings = {
        enableDefaultNetwork = false;
        imports = [ ./caddy ./minio ];
      };
    };
  };
}
