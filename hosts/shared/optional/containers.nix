{ pkgs, lib, ... }:
with lib;
{
  custom.defaultGroups = [
    "docker"
    "podman"
  ];

  environment.systemPackages = with pkgs; [ podman-tui ];

  virtualisation = {
    # Sadly there are still lots of things podman / podman-compose can't do
    # Until that day we are forced to use docker in these situations.
    # Mark my works, i will rid myself of docker one day..
    docker = {
      enable = mkForce true;
      package = pkgs.docker;

      daemon.settings.features.cdi = true;

      autoPrune = {
        enable = true;
        dates = "weekly";
        flags = [ ];
      };
    };

    oci-containers.backend = "docker";
  };

  host.persistence.directories =
    let
      docker = "/var/lib/docker";
    in
    [
      "${docker}/overlay2"
      "${docker}/image"
      "${docker}/volumes"
      "${docker}/containers"
    ];

  networking.firewall.allowedTCPPorts = [ 2375 ];
}
