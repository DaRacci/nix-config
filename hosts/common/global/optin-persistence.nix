# This file defines the "non-hardware dependent" part of opt-in persistence
# It imports impermanence, defines the basic persisted dirs, and ensures each
# users' home persist dir exists and has the right permissions
#
# It works even if / is tmpfs, btrfs snapshot, or even not ephemeral at all.
{ lib, inputs, config, ... }:

let
  persisted-logs = [
    { directory = /var/log; user = "root"; group = "root"; mode = "u=rwx,g=rx,o="; }
  ];

  persisted-other = [
    # TODO :: Should this be a specific group & user?
    { directory = /var/lib/bluetooth; user = "root"; group = "root"; mode = "u=rwx,g=,o="; }
    { directory = "/var/lib/colord"; user = "colord"; group = "colord"; mode = "u=rwx,g=rx,o="; }
  ];
in {
  imports = [
    inputs.impermanence.nixosModules.impermanence
  ];

  environment.persistence."/persist" = {
    directories = [
      { directory = /var/log; user = "root"; group = "root"; mode = "u=rwx,g=rx,o="; }
      # TODO :: Should this be a specific group & user?
      { directory = /var/lib/bluetooth; user = "root"; group = "root"; mode = "u=rwx,g=,o="; }
      { directory = /var/lib/colord; user = "colord"; group = "colord"; mode = "u=rwx,g=rx,o="; }
      { directory = /var/lib/systemd; user = "root"; group = "root"; mode = "u=rwx,g=rx,o=rx"; }
      "/var/lib/nixos"
    ];
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
    in lib.concatLines (map mkHomePersist users);
}