{ config, flake, options, lib, hasPersistence, ... }:
let
  isEd25519 = k: k.type == "ed25519";
  getKeyPath = k: k.path;
  keys = builtins.filter isEd25519 config.services.openssh.hostKeys;
in
{
  imports = [ flake.inputs.sops-nix.nixosModules.sops ];

  sops = {
    age.sshKeyPaths = map getKeyPath keys;
  };
} // lib.optionalAttrs (hasPersistence) {
  environment.persistence."/persist".files = [
    "/etc/ssh/ssh_host_ed25519_key"
    "/etc/ssh/ssh_host_ed25519_key.pub" # Maybe copy from repo?
  ];
}
