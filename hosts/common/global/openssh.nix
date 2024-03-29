{ hostDir, outputs, config, pkgs, lib, ... }:

let
  inherit (config.networking) hostName;
  hosts = outputs.nixosConfigurations;
  pubKey = host: "${hostDir}/ssh_host_ed25519_key.pub";

  # Sops needs acess to the keys before the persist dirs are even mounted; so
  # just persisting the keys won't work, we must point at /persist
  inherit (import ../../../lib/persistence.nix { inherit lib; inherit (config) host; }) persistable;

  hostSSHPubKey = pkgs.writeTextFile {
    name = "ssh_host_ed25519_key.pub";
    text = builtins.readFile "${hostDir}/ssh_host_ed25519_key.pub";
  };

  hostSSHPrivKey = pkgs.writeTextFile {
    name = "ssh_host_ed25519_key";
    text = builtins.readFile config.sops.secrets.SSH_PRIVATE_KEY.path;
  };
in
{
  environment.etc = { };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      GatewayPorts = "clientspecified";
    };

    hostKeys = [{
      path = persistable "/etc/ssh/ssh_host_ed25519_key";
      type = "ed25519";
    }];
  };

  programs.ssh = {
    # Each hosts public key
    knownHosts = builtins.mapAttrs
      (name: _: {
        publicKeyFile = pubKey name;
        extraHostNames = (lib.optional (name == hostName) "localhost"); # Alias for localhost if it's the same host
      })
      hosts;
  };

  users.users.root = {
    openssh.authorizedKeys.keys = [ (builtins.readFile "${hostDir}/ssh_host_ed25519_key.pub") ];
  };

  # Passwordless sudo when SSH'ing with keys
  security.pam.enableSSHAgentAuth = true;
}
