{ flake, config, pkgs, lib, ... }:
let
  inherit (config.home) username;

  privateKey = pkgs.writeTextFile {
    name = "${config.host.name}_ed25519";
    text = builtins.readFile config.sops.secrets.SSH_PRIVATE_KEY.path;
  };
in
{
  sops = {
    defaultSopsFile = "${flake}/home/${username}/secrets.yaml";

    age.sshKeyPaths = [ privateKey ];
  };
}
