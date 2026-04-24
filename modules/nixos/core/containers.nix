{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.core.containers;
in
{
  options.core.containers = {
    enable = mkEnableOption "container support";
  };

  config = mkIf cfg.enable {
    custom.defaultGroups = [ "docker" ];

    virtualisation = {
      # Sadly there are still lots of things podman / podman-compose can't do
      # Until that day we are forced to use docker in these situations.
      # Mark my works, i will rid myself of docker one day..
      docker = {
        enable = true;
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
        "${docker}/containerd"
        "${docker}/buildkit"
      ];

    networking.firewall.allowedTCPPorts = [ 2375 ];
  };
}
