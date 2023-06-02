{ ... }: {
  fileSystems = {
    "/" = {
      device = "none";
      fsType = "tmpfs";
      options = [ "defaults" "size=2G" "mode=755" ];
    };
  };

  environment.persistence = {
    "/persist/logs" = {
      hideMounts = true;

      directories = [
        "/var/log"
      ];
    };

    "/persist/sys" = {
      hideMounts = true;

      directories = [
        "/var/lib/bluetooth"
        "/var/lib/nixos"
        "/var/lib/systemd/coredump"
        "/etc/NetworkManager/system-connections"
      ];

      files = [
        "/etc/machine-id"
        { file = "/etc/nix/id_rsa"; parentDirectory = { mode = "u=rwx,g=,o="; }; }
      ];
    };
  };
}