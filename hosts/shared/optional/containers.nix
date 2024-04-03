{ config, pkgs, lib, ... }: with pkgs.lib; {
  environment.systemPackages = with pkgs; [
    podman-tui
    podman-compose
  ];

  virtualisation = {
    # Sadly there are still lots of things podman / podman-compose can't do
    # Until that day we are forced to use docker in these situations.
    # Mark my works, i will rid myself of docker one day..
    docker = {
      enable = mkForce true;
      enableNvidia = mkForce true;
      package = pkgs.unstable.docker;
    };

    oci-containers.backend = "podman";

    podman = {
      enable = true;
      package = pkgs.unstable.podman;

      defaultNetwork.settings.dns_name = true;

      dockerCompat = mkForce (!config.virtualisation.docker.enable);
      dockerSocket.enable = mkForce (!config.virtualisation.docker.enable);

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

  host.persistence.directories = let docker = "/var/lib/docker"; in [
    "${docker}/overlay2"
    "${docker}/image"
  ];
}
