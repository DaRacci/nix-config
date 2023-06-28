{
  fileSystems = {
    "/" = {
      device = "none";
      fsType = "tmpfs";
      options = [ "defaults" "size=16G" "mode=755" ];
    };
  };

  environment.persistence = {
    "/persist" = {
      hideMounts = true;

      directories = [
        "/var/log"
        "/var/lib/bluetooth"
        "/var/lib/nixos"
        "/var/lib/systemd/coredump"
        "/etc/NetworkManager/system-connections"
      ];

      files = [
        "/etc/machine-id"
        { file = "/etc/nix/id_rsa"; parentDirectory = { mode = "u=rwx,g=rx,o=rx"; }; }
      ];
    };
  };
}
