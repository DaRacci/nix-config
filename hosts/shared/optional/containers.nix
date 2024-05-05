{ pkgs, lib, ... }: with lib; {
  environment.systemPackages = with pkgs; [
    podman-tui
  ];

  virtualisation = {
    # Sadly there are still lots of things podman / podman-compose can't do
    # Until that day we are forced to use docker in these situations.
    # Mark my works, i will rid myself of docker one day..
    docker = {
      enable = mkForce true;
      enableNvidia = mkForce true;
      package = pkgs.unstable.docker;

      # logDriver = "journald";
      # storageDriver = "btrfs";

      listenOptions = [
        "unix:///var/run/docker.sock"
        "tcp:///0.0.0.0:2375"
      ];

      autoPrune = {
        enable = true;
        dates = "weekly";
        flags = [ ];
      };
    };

    oci-containers.backend = "docker";
  };

  host.persistence.directories = let docker = "/var/lib/docker"; in [
    "${docker}/overlay2"
    "${docker}/image"
    "${docker}/volumes"
    "${docker}/containers"
  ];

  networking.firewall.allowedTCPPorts = [ 2375 ];
}
