# This file defines the "non-hardware dependent" part of opt-in persistence
# It imports impermanence, defines the basic persisted dirs, and ensures each
# users' home persist dir exists and has the right permissions
#
# It works even if / is tmpfs, btrfs snapshot, or even not ephemeral at all.
{ lib, flake, config, ... }: {
  imports = [
    flake.inputs.impermanence.nixosModules.impermanence
  ];

  environment.persistence = {
    "/persist" = {
      hideMounts = true;
      
      directories = [
        "/var/lib/bluetooth"
        "/var/lib/systemd"
        "/var/lib/nixos"
        "/var/log"
        "/etc/NetworkManager/system-connections"
      ];

      files = [
        "/etc/machine-id"
        { file = "/etc/nix/id_rsa"; parentDirectory = { mode = "u=rwx,g=rx,o=rx"; }; }
      ];
    };
  };

  programs.fuse.userAllowOther = true;

  system.activationScripts.persistent-dirs.text =
    let
      mkHomePersist = user: lib.optionalString user.createHome ''
        mkdir -p /persist/${user.home}
        chown ${user.name}:${user.group} /persist/${user.home}
        chmod ${user.homeMode} /persist/${user.home}
      '';
      users = lib.attrValues config.users.users;
    in
    lib.concatLines (map mkHomePersist users);
}