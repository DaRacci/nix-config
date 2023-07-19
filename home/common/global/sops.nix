{ lib, config, ... }:
let
  inherit (config.home) username;
  inherit (import ../../../lib lib) persistablePath;
in
{
  sops = {
    defaultSopsFile = ../../${username}/secrets.yaml;

    # TODO - Get from 1Password
    age.sshKeyPaths = [ (persistablePath "/home/${username}/.ssh/id_ed25519") ];
  };
}
