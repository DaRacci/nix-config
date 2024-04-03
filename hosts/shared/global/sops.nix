{ flake, config, hostDirectory, ... }:
let
  isEd25519 = k: k.type == "ed25519";
  getKeyPath = k: k.path;
  keys = builtins.filter isEd25519 config.services.openssh.hostKeys;
in
{
  imports = [ flake.inputs.sops-nix.nixosModules.sops ];

  sops = {
    age.sshKeyPaths = map getKeyPath keys;
    defaultSopsFile = "${hostDirectory}/secrets.yaml";

    secrets = {
      SSH_PRIVATE_KEY = { };
    };
  };
}
