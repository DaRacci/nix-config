{ pkgs, inputs, ... }: {
  imports = [
    inputs.arion.nixosModules.arion
  ];

  environment.systemPackages = with pkgs; [
    podman-tui
    podman-compose
    lollms-webui
    lollms
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
        networks.outside = {
          name = "outside";
          internal = false;
          attachable = false;
          enable_ipv6 = false; # TODO :: Learn IPv6
          ipam.config = [{
            subnet = "10.10.9.0/24";
            ip_range = "10.10.9.0/24";
            gateway = "10.10.9.1";
          }];
        };

        imports = [ ./caddy ./lollms ];
      };
    };
  };

  networking.nat = {
    enable = true;
    internalInterfaces = [ "ve-+" ];
    externalInterface = "eth0";
    enableIPv6 = false;
  };
}
