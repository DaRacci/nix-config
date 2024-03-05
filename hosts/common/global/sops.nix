{ flake, config, hostDir, ... }:
let
  isEd25519 = k: k.type == "ed25519";
  getKeyPath = k: k.path;
  keys = builtins.filter isEd25519 config.services.openssh.hostKeys;
in
{
  imports = [ flake.inputs.sops-nix.nixosModules.sops ];

  sops = {
    age.sshKeyPaths = map getKeyPath keys;
    defaultSopsFile = "${hostDir}/secrets.yaml";
  };

  # system.activationScripts.copy-ssh-keys = lib.stringAfter [ ] ''
  #   mkdir -p /etc/ssh

  #   if [ -f /etc/ssh/ssh_host_ed25519_key.pub ]; then
  #     # Check if the key is correct
  #     if ! ssh-keygen -l -f /etc/ssh/ssh_host_ed25519_key.pub | grep -q "$(${pkgs.cat} ${builtins.toString keys[0].path}.pub | cut -d' ' -f2)"; then
  #       echo "SSH key is incorrect, removing"
  #       rm -f /etc/ssh/ssh_host_ed25519_key
  #       rm -f /etc/ssh/ssh_host_ed25519_key.pub
  #     fi
  #   else
  #     echo "Copying SSH keys"
  #     cp -r ${builtins.toString keys} /etc/ssh
  #   fi
  # '';

  host.persistence.files = [
    "/etc/ssh/ssh_host_ed25519_key"
    "/etc/ssh/ssh_host_ed25519_key.pub" # Maybe copy from repo?
  ];
}
