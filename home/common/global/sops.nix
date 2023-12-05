{ flake, config, lib, ... }:
let
  inherit (config.home) username;
  inherit (import "${flake}/lib" lib) persistablePath;
in
{
  sops = {
    defaultSopsFile = "${flake}/home/${username}/secrets.yaml";

    # TODO - Get from 1Password
    age.sshKeyPaths = [ (persistablePath "/home/${username}/.ssh/id_ed25519") ];
  };
}
